from time import monotonic, sleep
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jtag_stream import JtagStreamHalfDuplex


class MemClient:
    READ_FLAG = 0x80000000

    def __init__(self, stream: "JtagStreamHalfDuplex"):
        self.stream = stream

    def write_reg(self, addr: int, data: int) -> None:
        self.stream.send_word(addr & ~self.READ_FLAG, message_start=True)
        self.stream.send_word(data & 0xFFFFFFFF)

    def read_reg(self, addr: int, timeout: float = 1.0) -> int:
        self.stream.recv_available()
        self.stream.send_word(self.READ_FLAG | (addr & ~self.READ_FLAG), message_start=True)
        self.stream.send_word(0)

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
