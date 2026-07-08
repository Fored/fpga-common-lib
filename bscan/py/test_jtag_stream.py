import unittest

from jtag_stream import JtagStreamHalfDuplex


class FakeJtag:
    def __init__(self, tdo_values):
        self.tdo_values = list(tdo_values)
        self.calls = []
        self.many_calls = []

    def dr_scan(self, tdi_val, nbits):
        self.calls.append((tdi_val, nbits))
        return self.tdo_values.pop(0)

    def dr_scan_many(self, tdi_values, nbits):
        self.many_calls.append((tdi_values, nbits))
        result = self.tdo_values[: len(tdi_values)]
        del self.tdo_values[: len(tdi_values)]
        return result


class JtagStreamHalfDuplexTest(unittest.TestCase):
    def test_send_word_adds_signature_and_decodes_signed_response(self):
        request_signature = JtagStreamHalfDuplex.REQUEST_SIGNATURE << 34
        response_signature = JtagStreamHalfDuplex.RESPONSE_SIGNATURE << 34
        response = response_signature | (1 << 33) | (1 << 32) | 0x89ABCDEF
        jtag = FakeJtag([response])
        stream = JtagStreamHalfDuplex(jtag)

        stream.send_word(0x123456789, message_start=True)

        expected_word = request_signature | (1 << 33) | (1 << 32) | 0x23456789
        self.assertEqual(jtag.calls, [(expected_word, 50)])
        self.assertEqual(stream.recv_available(), [(0x89ABCDEF, True)])

    def test_poll_sends_signed_frame_without_valid_data(self):
        request_signature = JtagStreamHalfDuplex.REQUEST_SIGNATURE << 34
        response_signature = JtagStreamHalfDuplex.RESPONSE_SIGNATURE << 34
        jtag = FakeJtag([response_signature])
        stream = JtagStreamHalfDuplex(jtag)

        self.assertFalse(stream.poll())
        self.assertEqual(jtag.calls, [(request_signature, 50)])

    def test_send_words_batches_dr_scans_and_preserves_message_starts(self):
        request_signature = JtagStreamHalfDuplex.REQUEST_SIGNATURE << 34
        response_signature = JtagStreamHalfDuplex.RESPONSE_SIGNATURE << 34
        jtag = FakeJtag([response_signature, response_signature])
        stream = JtagStreamHalfDuplex(jtag)

        stream.send_words([0x1111, 0x2222], message_starts=[True, True])

        self.assertEqual(
            jtag.many_calls,
            [([request_signature | (1 << 33) | (1 << 32) | 0x1111,
               request_signature | (1 << 33) | (1 << 32) | 0x2222], 50)],
        )

    def test_rejects_response_without_signature(self):
        jtag = FakeJtag([0])
        stream = JtagStreamHalfDuplex(jtag)

        with self.assertRaisesRegex(RuntimeError, "Invalid BSCAN frame signature"):
            stream.poll()


if __name__ == "__main__":
    unittest.main()
