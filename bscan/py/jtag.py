from xvc_client import XvcClient


def int_to_bits_lsb(x: int, nbits: int):
    return [(x >> i) & 1 for i in range(nbits)]

def bits_to_int_lsb_first_at(b: bytes, offset: int, nbits: int):
    val = 0
    for i in range(nbits):
        pos = offset + i
        if (b[pos >> 3] >> (pos & 7)) & 1:
            val |= (1 << i)
    return val

class Jtag:
    def __init__(self, xc: XvcClient):
        self.xc = xc
        self.reset_to_idle()

    def reset_to_idle(self):
        # 6×TMS=1 -> TLR, затем 1×TMS=0 -> RTI
        self.xc.shift([1]*6 + [0], [0]*7, 7)

    def goto_shift_ir(self):
        # RTI -> Select-DR(1) -> Select-IR(1) -> Capture-IR(0) -> Shift-IR(0)
        self.xc.shift([1,1,0,0], [0,0,0,0], 4)

    def ir_scan(self, value: int, nbits: int):
        tms = [1, 1, 0, 0] + [0]*(nbits-1) + [1] + [1, 0]
        tdi = [0, 0, 0, 0] + int_to_bits_lsb(value, nbits) + [0, 0]
        self.xc.shift(tms, tdi, len(tms))

    def dr_scan(self, tdi_val: int, nbits: int) -> int:
        return self.dr_scan_many([tdi_val], nbits)[0]

    def dr_scan_many(self, tdi_values, nbits: int) -> list[int]:
        if nbits <= 0:
            raise ValueError("nbits must be positive")
        if not tdi_values:
            return []

        tms = []
        tdi = []
        for tdi_val in tdi_values:
            tms += [1, 0, 0] + [0]*(nbits-1) + [1] + [1, 0]
            tdi += [0, 0, 0] + int_to_bits_lsb(tdi_val, nbits) + [0, 0]

        tdo = self.xc.shift(tms, tdi, len(tms))
        scan_width = nbits + 5
        return [bits_to_int_lsb_first_at(tdo, index * scan_width + 3, nbits) for index in range(len(tdi_values))]
