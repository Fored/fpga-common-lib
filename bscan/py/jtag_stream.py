import logging


class JtagStreamHalfDuplex:
    """
    Полудуплексный поток через bscan_to_stream.
    Любая операция записи проверяет, не пришли ли встречные данные.
    """

    def __init__(self, jtag, data_width):
        self.j = jtag
        self.rx_buffer = []
        self.data_width = data_width

    def _decode_tdo(self, tdo: int):
        valid = bool((tdo >> self.data_width) & 1)
        msg_start = bool((tdo >> (self.data_width + 1)) & 1)
        data = tdo & 0xFFFFFFFF
        return valid, msg_start, data

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
        word = ((1 if message_start else 0) << (self.data_width + 1)) | (1 << self.data_width) | (data & 0xFFFFFFFF)
        tdo = self.j.dr_scan(word, self.data_width + 2)
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
            tdo = self.j.dr_scan(0, self.data_width + 2)
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
