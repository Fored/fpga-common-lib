import socket, struct, sys


def pack_bits_lsb_first(bits):
    out = bytearray((len(bits) + 7) // 8)
    for i, b in enumerate(bits):
        if b & 1:
            out[i >> 3] |= 1 << (i & 7)
    return bytes(out)


class XvcClient:
    def __init__(self, host="127.0.0.1", port=2542, timeout=5.0, default_ir_len=6):
        self.s = socket.create_connection((host, port), timeout=timeout)
        self.s.settimeout(timeout)
        self.max_bits, self.ir_len = self._getinfo(default_ir_len)

    def close(self):
        try:
            self.s.close()
        except:
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

    def _getinfo(self, default_ir_len):
        self.s.sendall(b"getinfo:")
        buf = b""
        # читаем немного, пока не увидим хотя бы два поля
        while buf.count(b":") < 1 and len(buf) < 128:
            chunk = self._recv_some(64)
            if not chunk:
                break
            buf += chunk
        text = buf.split(b"\n", 1)[0].decode(errors="ignore").strip()
        if not text:
            raise TimeoutError("XVC getinfo: no response")
        parts = text.split(":")
        if len(parts) == 3:
            maxbits = int(parts[1])
            irlen = int(parts[2])
        elif len(parts) == 2:
            maxbits = int(parts[1])
            irlen = int(default_ir_len)
            print(f"[XVC] getinfo='{text}'", file=sys.stderr)
        else:
            raise RuntimeError(f"Unexpected getinfo format: {text!r}")
        return maxbits, irlen

    def settck_hz(self, hz: int):
        if hz <= 0:
            return
        period_ns = max(1, int(1_000_000_000 // hz))
        self.s.sendall(b"settck:" + struct.pack("<I", period_ns))
        _ = self._recv_some(4)  # echo (best-effort)

    def shift(self, tms_bits, tdi_bits, nbits: int) -> bytes:
        """Команда shift: (LSB-first), с чанкованием по self.max_bits."""
        assert len(tms_bits) >= nbits and len(tdi_bits) >= nbits
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
