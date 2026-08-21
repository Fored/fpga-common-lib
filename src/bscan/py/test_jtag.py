import unittest

from jtag import Jtag


def bits_to_bytes(bits):
    result = bytearray((len(bits) + 7) // 8)
    for index, bit in enumerate(bits):
        result[index >> 3] |= bit << (index & 7)
    return bytes(result)


class FakeXvcClient:
    def __init__(self):
        self.calls = []
        self.next_tdo = b""

    def shift(self, tms, tdi, nbits):
        self.calls.append((tms, tdi, nbits))
        return self.next_tdo or bytes((nbits + 7) // 8)


class JtagTest(unittest.TestCase):
    def test_dr_scan_combines_tap_transitions_and_data_shift(self):
        xvc = FakeXvcClient()
        jtag = Jtag(xvc)  # type: ignore[arg-type]
        xvc.calls.clear()
        xvc.next_tdo = bits_to_bytes([0, 0, 0, 1, 0, 1, 0, 0])

        result = jtag.dr_scan(0b011, 3)

        self.assertEqual(xvc.calls, [([1, 0, 0, 0, 0, 1, 1, 0], [0, 0, 0, 1, 1, 0, 0, 0], 8)])
        self.assertEqual(result, 0b101)


if __name__ == "__main__":
    unittest.main()
