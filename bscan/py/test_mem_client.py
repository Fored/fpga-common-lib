import unittest

from mem_client import MemClient


class FakeStream:
    def __init__(self, received: list[list[tuple[int, bool]]] | None = None) -> None:
        self.sent: list[tuple[int, bool]] = []
        self.received = received or []

    def send_word(self, data: int, message_start: bool = False) -> None:
        self.sent.append((data, message_start))

    def poll(self) -> None:
        pass

    def recv_available(self) -> list[tuple[int, bool]]:
        if self.received:
            return self.received.pop(0)
        return []


class MemClientTest(unittest.TestCase):
    def test_write_reg_sends_address_marker_then_data(self) -> None:
        stream = FakeStream()
        mem = MemClient(stream)  # type: ignore[arg-type]

        mem.write_reg(0x80000005, 0x1_0000_0001)

        self.assertEqual(stream.sent, [(0x5, True), (0x1, False)])

    def test_read_reg_ignores_other_messages_until_requested_address(self) -> None:
        stream = FakeStream(
            [
                [],
                [(0x1, True), (0xAAAA, False)],
                [(0x2, True), (0x1234, False)],
            ]
        )
        mem = MemClient(stream)  # type: ignore[arg-type]

        self.assertEqual(mem.read_reg(0x2, timeout=0.1), 0x1234)
        self.assertEqual(stream.sent, [(0x80000002, True), (0, False)])


if __name__ == "__main__":
    unittest.main()
