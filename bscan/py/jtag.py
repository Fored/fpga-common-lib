
import sys

from xvc_client import XvcClient


def int_to_bits_lsb(x: int, nbits: int):
    return [(x >> i) & 1 for i in range(nbits)]

def bits_to_int_lsb_first(b: bytes, nbits: int):
    val = 0
    for i in range(nbits):
        if (b[i >> 3] >> (i & 7)) & 1:
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

    def goto_shift_dr(self):
        # RTI -> Select-DR(1) -> Capture-DR(0) -> Shift-DR(0)
        self.xc.shift([1,0,0], [0,0,0], 3)

    def ir_scan(self, value: int, nbits: int):
        self.goto_shift_ir()
        tms = [0]*(nbits-1) + [1]                # exit after last bit
        tdi = int_to_bits_lsb(value, nbits)
        self.xc.shift(tms, tdi, nbits)
        self.xc.shift([1,0], [0,0], 2)           # Exit1-IR -> Update-IR -> RTI

    def dr_scan(self, tdi_val: int, nbits: int) -> int:
        self.goto_shift_dr()
        tms = [0]*(nbits-1) + [1]
        tdi = int_to_bits_lsb(tdi_val, nbits)
        tdo = self.xc.shift(tms, tdi, nbits)
        self.xc.shift([1,0], [0,0], 2)           # Exit1-DR -> Update-DR -> RTI
        return bits_to_int_lsb_first(tdo, nbits)
