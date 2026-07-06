import unittest

from jtag_stream import JtagStreamHalfDuplex


class FakeJtag:
    def __init__(self, tdo_values):
        self.tdo_values = list(tdo_values)
        self.calls = []

    def dr_scan(self, tdi_val, nbits):
        self.calls.append((tdi_val, nbits))
        return self.tdo_values.pop(0)


class JtagStreamHalfDuplexTest(unittest.TestCase):
    def test_send_word_uses_32_data_bits_and_decodes_response(self):
        response = (1 << 33) | (1 << 32) | 0x89ABCDEF
        jtag = FakeJtag([response])
        stream = JtagStreamHalfDuplex(jtag)

        stream.send_word(0x123456789, message_start=True)

        expected_word = (1 << 33) | (1 << 32) | 0x23456789
        self.assertEqual(jtag.calls, [(expected_word, 34)])
        self.assertEqual(stream.recv_available(), [(0x89ABCDEF, True)])


if __name__ == "__main__":
    unittest.main()
