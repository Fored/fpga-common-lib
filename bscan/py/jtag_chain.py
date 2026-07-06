from dataclasses import dataclass
import logging
from typing import List


@dataclass
class TapDevice:
    name: str
    ir_len: int  # длина IR этого устройства (бит)
    ir_bypass: int  # опкод BYPASS для данного IR-кол-ва (обычно все 1)
    # позиция в цепочке задаётся списком JtagChain.devices (index)


class JtagChain:
    """
    Управление JTAG-цепочкой из N устройств поверх твоего Jtag.
    Порядок devices совпадает с iMPACT: index=0 — ближайшее к TDI,
    последний — ближайший к TDO.
    """

    def __init__(self, jtag, devices: List[TapDevice]):
        self.jtag = jtag
        self.devices = devices
        self.current_device = None

    # ---------- ВСПОМОГАТЕЛЬНОЕ ----------
    @staticmethod
    def _int_to_bits_lsb(x: int, nbits: int) -> List[int]:
        return [(x >> i) & 1 for i in range(nbits)]

    # ---------- IR ОПЕРАЦИИ ----------
    def set_ir_all(self, ir_values: List[int]) -> None:
        """
        Установить инструкции всем устройствам одной общей IR-операцией.
        ir_values[i] — инструкция для devices[i], LSB-first.
        """
        if len(ir_values) != len(self.devices):
            raise ValueError("IR value count must match device count")

        total_ir_bits = sum(d.ir_len for d in self.devices)
        # Первые биты, вошедшие через TDI, доходят до ближайшего к TDO TAP.
        tdi_bits: List[int] = []
        for ir, dev in reversed(list(zip(ir_values, self.devices))):
            tdi_bits += self._int_to_bits_lsb(ir, dev.ir_len)

        # Сдвиг IR всей цепочки
        self.jtag.goto_shift_ir()
        # Последний бит всей цепочки должен выйти в Exit1-IR → TMS для последнего бита = 1
        tms = [0] * (total_ir_bits - 1) + [1]
        self.jtag.xc.shift(tms, tdi_bits, total_ir_bits)
        # Exit1-IR -> Update-IR -> Idle
        self.jtag.xc.shift([1, 0], [0, 0], 2)

    def set_ir_bypass_all(self) -> None:
        self.set_ir_all([d.ir_bypass for d in self.devices])

    def set_ir_target(self, target: str, ir_code: int) -> None:
        """
        Всем BYPASS, целевому устройству — ir_code.
        """
        irs = [d.ir_bypass for d in self.devices]
        idx = self.index_of(target)
        self.current_device = idx
        irs[idx] = ir_code
        self.set_ir_all(irs)

    # ---------- DR ОПЕРАЦИИ ----------
    def dr_scan(self, tdi_val: int, target_nbits: int) -> int:
        """
        Один DR-скан через всю цепочку, где у нецелевых TAP BYPASS=1 бит,
        а у целевого — target_nbits. Вернёт TDO целевого устройства как int.
        """
        if target_nbits <= 0:
            raise ValueError("target_nbits must be positive")
        if self.current_device is None:
            raise RuntimeError("Target TAP is not selected")
        idx = self.current_device

        # Общая длина DR — сумма по всем: для BYPASS = 1, для target = target_nbits
        total_dr_bits = (len(self.devices) - 1) * 1 + target_nbits

        # Собираем TDI-биты от ближайшего к TDO устройства к ближайшему к TDI.
        # Для нецелевых — 0 (или как нужно), для целевого — tdi_val (LSB-first)
        tdi_bits: List[int] = []
        for i in reversed(range(len(self.devices))):
            if i == idx:
                tdi_bits += self._int_to_bits_lsb(tdi_val & ((1 << target_nbits) - 1), target_nbits)
            else:
                tdi_bits += [0]  # DR BYPASS = 1 бит, кладём 0 (обычно без разницы)

        # Сдвигаем DR всю цепочку (последний бит — TMS=1 для Exit1-DR)
        self.jtag.goto_shift_dr()
        tms = [0] * (total_dr_bits - 1) + [1]
        tdo_bytes = self.jtag.xc.shift(tms, tdi_bits, total_dr_bits)
        self.jtag.xc.shift([1, 0], [0, 0], 2)  # Exit1-DR -> Update-DR -> Idle

        # Первыми из TDO выходят данные ближайшего к TDO устройства.
        # Каждый нецелевой TAP после целевого в devices даёт один BYPASS-бит.
        offset = len(self.devices) - idx - 1
        # Собираем target_nbits из tdo_bytes, начиная с offset
        val = 0
        for k in range(target_nbits):
            # позиция k+offset
            pos = offset + k
            byte = tdo_bytes[pos >> 3]
            bit = (byte >> (pos & 7)) & 1
            val |= bit << k
        logging.debug(f"DR_SCAN: 0x{val:09X}")
        return val

    # ---------- УТИЛИТЫ ----------
    def index_of(self, name: str) -> int:
        for i, d in enumerate(self.devices):
            if d.name == name:
                return i
        raise KeyError(f"TAP '{name}' not found")
