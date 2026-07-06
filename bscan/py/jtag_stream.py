import logging


class JtagStreamHalfDuplex:
    """
    Полудуплексный поток через bscan_to_stream.
    Любая операция записи проверяет, не пришли ли встречные данные.
    """

    DATA_WIDTH = 32
    DATA_MASK = (1 << DATA_WIDTH) - 1
    REQUEST_SIGNATURE = 0xB5CA
    RESPONSE_SIGNATURE = 0xCA5B
    SIGNATURE_WIDTH = 16
    SIGNATURE_SHIFT = DATA_WIDTH + 2
    SCAN_WIDTH = SIGNATURE_SHIFT + SIGNATURE_WIDTH

    def __init__(self, jtag):
        self.j = jtag
        self.rx_buffer = []

    def _decode_tdo(self, tdo: int):
        signature = (tdo >> self.SIGNATURE_SHIFT) & ((1 << self.SIGNATURE_WIDTH) - 1)
        if signature != self.RESPONSE_SIGNATURE:
            raise RuntimeError(f"Invalid BSCAN frame signature: 0x{signature:04X}")

        valid = bool((tdo >> self.DATA_WIDTH) & 1)
        msg_start = bool((tdo >> (self.DATA_WIDTH + 1)) & 1)
        data = tdo & self.DATA_MASK
        return valid, msg_start, data

    def _encode_frame(self, data=0, valid=False, message_start=False):
        return (
            (self.REQUEST_SIGNATURE << self.SIGNATURE_SHIFT)
            | ((1 if message_start else 0) << (self.DATA_WIDTH + 1))
            | ((1 if valid else 0) << self.DATA_WIDTH)
            | (data & self.DATA_MASK)
        )

    def _handle_tdo(self, tdo: int):
        valid, msg_start, data = self._decode_tdo(tdo)
        if valid:
            self.rx_buffer.append((data, msg_start))
            return True
        else:
            return False

    # ---------- передача ----------
    def send_word(self, data: int, message_start=False):
        logging.debug(f"Sending word: 0x{data:08X}, message_start: {message_start}")
        word = self._encode_frame(data, valid=True, message_start=message_start)
        tdo = self.j.dr_scan(word, self.SCAN_WIDTH)
        self._handle_tdo(tdo)

    def send_words(self, data_list, start_flag=True):
        for i, w in enumerate(data_list):
            self.send_word(w, message_start=(start_flag and i == 0))

    # ---------- приём ----------
    def recv_available(self):
        """Вернуть всё, что накопилось в буфере."""
        out = self.rx_buffer[:]
        self.rx_buffer.clear()
        return out

    def poll(self, num=1):
        """Считать несколько слов без записи (poll FIFO на стороне ПЛИС)."""
        for _ in range(num):
            tdo = self.j.dr_scan(self._encode_frame(), self.SCAN_WIDTH)
            if not self._handle_tdo(tdo):
                return False
        return True

    def recv_blocking(self, timeout=0.1):
        """Ждать первое слово (с poll’ом)"""
        import time

        t0 = time.time()
        while time.time() - t0 < timeout:
            if self.poll():
                return True
        return False

    def poll_all(self):
        """Считать все доступные слова (с poll’ом)"""
        attempts = 1
        while True:
            logging.debug(f"Polling attempt {attempts}")
            if not self.poll():
                break
            attempts += 1
