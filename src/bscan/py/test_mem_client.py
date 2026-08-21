import unittest

from mem_client import MemClient


class FakeStream:
    def __init__(self, received: list[list[tuple[int, bool]]] | None = None) -> None:
        self.sent: list[tuple[int, bool]] = []
        self.received = received or []

    def send_word(self, data: int, message_start: bool = False) -> None:
        self.sent.append((data, message_start))

    def send_words(self, data_list, start_flag: bool = True, message_starts=None) -> None:
        if message_starts is None:
            message_starts = [(start_flag and i == 0) for i, _ in enumerate(data_list)]
        for data, message_start in zip(data_list, message_starts):
            self.send_word(data, message_start=message_start)

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

    def test_read_regs_sends_all_requests_before_collecting_values(self) -> None:
        stream = FakeStream(
            [
                [],
                [(0x1, True), (0xAAAA, False)],
                [(0x2, False), (0xBBBB, False), (0x3, False), (0xCCCC, False)],
            ]
        )
        mem = MemClient(stream)  # type: ignore[arg-type]

        self.assertEqual(mem.read_regs([0x1, 0x2, 0x3], timeout=0.1), {0x1: 0xAAAA, 0x2: 0xBBBB, 0x3: 0xCCCC})
        self.assertEqual(
            stream.sent,
            [(0x80000001, True), (0, False), (0x80000002, False), (0, False), (0x80000003, False), (0, False)],
        )

    def test_read_regs_rejects_duplicate_addresses(self) -> None:
        mem = MemClient(FakeStream())  # type: ignore[arg-type]

        with self.assertRaisesRegex(ValueError, "unique"):
            mem.read_regs([0x1, 0x1])


if __name__ == "__main__":
    unittest.main()
