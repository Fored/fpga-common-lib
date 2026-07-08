from time import monotonic, sleep
import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jtag_stream import JtagStreamHalfDuplex


class MemClient:
    READ_FLAG = 0x80000000

    def __init__(self, stream: "JtagStreamHalfDuplex"):
        self.stream = stream

    def write_reg(self, addr: int, data: int) -> None:
        logging.info("MEM write: addr=%d data=0x%08X", addr & ~self.READ_FLAG, data & 0xFFFFFFFF)
        self.stream.send_words([addr & ~self.READ_FLAG, data & 0xFFFFFFFF])

    def read_reg(self, addr: int, timeout: float = 1.0) -> int:
        logging.info("MEM read: addr=%d", addr & ~self.READ_FLAG)
        self.stream.recv_available()
        self.stream.send_words([self.READ_FLAG | (addr & ~self.READ_FLAG), 0])

        seen_addr = False
        deadline = monotonic() + timeout
        while monotonic() < deadline:
            self.stream.poll()
            for data, message_start in self.stream.recv_available():
                if message_start:
                    seen_addr = (data & ~self.READ_FLAG) == addr
                elif seen_addr:
                    return data
            sleep(0.01)

        raise TimeoutError(f"Timeout while reading register {addr}")

    def read_regs(self, addrs: list[int], timeout: float = 1.0) -> dict[int, int]:
        if not addrs:
            return {}

        normalized = [addr & ~self.READ_FLAG for addr in addrs]
        if len(set(normalized)) != len(normalized):
            raise ValueError("Register addresses must be unique")

        logging.info("MEM read_regs: %d addresses, %d stream words", len(normalized), len(normalized) * 2)
        values: dict[int, int] = {}
        in_response = False
        seen_addr: int | None = None
        expect_data = False

        self.stream.recv_available()
        request_words: list[int] = []
        for addr in normalized:
            request_words.extend([self.READ_FLAG | addr, 0])
        self.stream.send_words(request_words)

        deadline = monotonic() + timeout
        while monotonic() < deadline:
            for data, message_start in self.stream.recv_available():
                if message_start:
                    addr = data & ~self.READ_FLAG
                    in_response = addr == normalized[0]
                    seen_addr = addr if in_response else None
                    expect_data = in_response
                elif in_response and expect_data and seen_addr is not None:
                    values[seen_addr] = data
                    seen_addr = None
                    expect_data = False
                    if len(values) == len(normalized):
                        return values
                elif in_response:
                    addr = data & ~self.READ_FLAG
                    seen_addr = addr if addr in normalized and addr not in values else None
                    expect_data = seen_addr is not None
            self.stream.poll()
            sleep(0.01)

        missing = ", ".join(str(addr) for addr in normalized if addr not in values)
        raise TimeoutError(f"Timeout while reading registers: {missing}")
