import unittest

from jtag_chain import JtagChain, TapDevice


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


class FakeJtag:
    def __init__(self):
        self.xc = FakeXvcClient()

    def goto_shift_ir(self):
        pass


class JtagChainTest(unittest.TestCase):
    def setUp(self):
        self.jtag = FakeJtag()
        self.chain = JtagChain(
            self.jtag,
            [
                TapDevice("TDI_DEVICE", 2, 0b11),
                TapDevice("MIDDLE_DEVICE", 3, 0b111),
                TapDevice("TDO_DEVICE", 4, 0b1111),
            ],
        )

    def test_ir_is_shifted_from_tdo_device_to_tdi_device(self):
        self.chain.set_ir_all([0b01, 0b010, 0b1010])

        _, tdi, nbits = self.jtag.xc.calls[0]
        self.assertEqual(nbits, 9)
        self.assertEqual(tdi, [0, 1, 0, 1, 0, 1, 0, 1, 0])

    def test_ir_value_count_must_match_device_count(self):
        with self.assertRaisesRegex(ValueError, "IR value count"):
            self.chain.set_ir_all([0b01])

        self.assertEqual(self.jtag.xc.calls, [])

    def test_dr_requires_selected_target(self):
        with self.assertRaisesRegex(RuntimeError, "Target TAP is not selected"):
            self.chain.dr_scan(0, 3)

        self.assertEqual(self.jtag.xc.calls, [])

    def test_dr_requires_positive_target_width(self):
        with self.assertRaisesRegex(ValueError, "target_nbits must be positive"):
            self.chain.dr_scan(0, 0)

        self.assertEqual(self.jtag.xc.calls, [])

    def test_dr_uses_impact_order_for_target_and_result(self):
        self.chain.set_ir_target("TDI_DEVICE", 0b01)
        self.jtag.xc.calls.clear()
        self.jtag.xc.next_tdo = bits_to_bytes([0, 0, 0, 0, 0, 1, 0, 1, 0, 0])

        result = self.chain.dr_scan(0b011, 3)

        _, tdi, nbits = self.jtag.xc.calls[0]
        self.assertEqual(nbits, 10)
        self.assertEqual(tdi, [0, 0, 0, 0, 0, 1, 1, 0, 0, 0])
        self.assertEqual(result, 0b101)


if __name__ == "__main__":
    unittest.main()
