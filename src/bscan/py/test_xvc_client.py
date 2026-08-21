import unittest

from xvc_client import XvcClient


class FakeSocket:
    def __init__(self, responses):
        self.responses = list(responses)
        self.sent = []

    def sendall(self, data):
        self.sent.append(data)

    def recv(self, _size):
        if not self.responses:
            return b""
        return self.responses.pop(0)


class XvcClientTest(unittest.TestCase):
    def setUp(self):
        self.client = XvcClient.__new__(XvcClient)

    def test_getinfo_reads_fragmented_response_until_newline(self):
        self.client.s = FakeSocket([b"xvcServer_v1.0:", b"20", b"48\n"])

        result = self.client._getinfo()

        self.assertEqual(result, 2048)
        self.assertEqual(self.client.s.sent, [b"getinfo:"])

    def test_getinfo_rejects_incomplete_response(self):
        self.client.s = FakeSocket([b"xvcServer_v1.0:2048"])

        with self.assertRaisesRegex(TimeoutError, "incomplete response"):
            self.client._getinfo()

    def test_getinfo_rejects_non_positive_max_bits(self):
        self.client.s = FakeSocket([b"xvcServer_v1.0:0\n"])

        with self.assertRaisesRegex(RuntimeError, "invalid max bits"):
            self.client._getinfo()

    def test_shift_requires_positive_bit_count(self):
        with self.assertRaisesRegex(ValueError, "nbits must be positive"):
            self.client.shift([], [], 0)

    def test_shift_requires_sufficient_vectors(self):
        with self.assertRaisesRegex(ValueError, "at least nbits bits"):
            self.client.shift([0], [0], 2)


if __name__ == "__main__":
    unittest.main()
