import socket
import struct


def pack_bits_lsb_first(bits):
    out = bytearray((len(bits) + 7) // 8)
    for i, b in enumerate(bits):
        if b & 1:
            out[i >> 3] |= 1 << (i & 7)
    return bytes(out)


class XvcClient:
    def __init__(self, host="127.0.0.1", port=2542, timeout=5.0):
        self.s = socket.create_connection((host, port), timeout=timeout)
        self.s.settimeout(timeout)
        self.max_bits = self._getinfo()

    def close(self):
        try:
            self.s.close()
        except OSError:
            pass

    def _recv_exact(self, n: int) -> bytes:
        buf = b""
        while len(buf) < n:
            chunk = self.s.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("XVC: connection closed")
            buf += chunk
        return buf

    def _recv_some(self, n=128) -> bytes:
        try:
            return self.s.recv(n)
        except socket.timeout:
            return b""

    def _getinfo(self):
        self.s.sendall(b"getinfo:")
        buf = b""
        max_response_bytes = 128
        while b"\n" not in buf and len(buf) < max_response_bytes:
            chunk = self._recv_some(min(64, max_response_bytes - len(buf)))
            if not chunk:
                break
            buf += chunk

        if not buf:
            raise TimeoutError("XVC getinfo: no response")
        if b"\n" not in buf:
            if len(buf) >= max_response_bytes:
                raise RuntimeError("XVC getinfo: response is too long")
            raise TimeoutError(f"XVC getinfo: incomplete response: {buf!r}")

        text = buf.split(b"\n", 1)[0].decode(errors="ignore").strip()
        parts = text.split(":")
        if len(parts) != 2:
            raise RuntimeError(f"Unexpected getinfo format: {text!r}")
        maxbits = int(parts[1])
        if maxbits <= 0:
            raise RuntimeError(f"XVC getinfo: invalid max bits: {maxbits}")
        return maxbits

    def shift(self, tms_bits, tdi_bits, nbits: int) -> bytes:
        """Команда shift: (LSB-first), с чанкованием по self.max_bits."""
        if nbits <= 0:
            raise ValueError("nbits must be positive")
        if len(tms_bits) < nbits or len(tdi_bits) < nbits:
            raise ValueError("TMS and TDI vectors must contain at least nbits bits")

        out = bytearray()
        pos = 0
        while pos < nbits:
            chunk = min(self.max_bits, nbits - pos)
            tms_chunk = pack_bits_lsb_first(tms_bits[pos : pos + chunk])
            tdi_chunk = pack_bits_lsb_first(tdi_bits[pos : pos + chunk])
            self.s.sendall(b"shift:" + struct.pack("<I", chunk) + tms_chunk + tdi_chunk)
            out += self._recv_exact((chunk + 7) // 8)
            pos += chunk
        return bytes(out)
