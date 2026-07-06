# Модуль взаимодействия python c FPGA

  Используя компонент BSCAN на FPGA и XVCServer на ПК можно реализовать взаимодействие с FPGA в тестовых, отладочных целях

## XVCServer

Для взаимодействия нужно запустить Xilinx Virtual Cable Server на ПК подключенным к FPGA через программатор. Обязательно осободи программатор в Vivado/impact после прошивки.

```bash
git clone https://github.com/tgingold-cern/xpcu-xvcd
cd xpcu-xvcd
sudo dnf install -y libusb1-devel
make
./xvcd
```

## Chipscope

Для возможности подключить chipscope к XVC:

JTAG Chain -> Open Plug-In...

```
xilinx_xvc host=127.0.0.1:2542 disableversioncheck=true
```

## Python

Каждый обмен выполняется 50-битным кадром:

```text
[49:34]  сигнатура запроса 0xB5CA / ответа 0xCA5B
[33]     начало сообщения
[32]     признак корректных данных
[31:0]   данные
```

Сигнатура проверяется для каждой транзакции, поэтому посторонние JTAG-сканы не
записываются во входной FIFO и не извлекают данные из выходного FIFO.

### IDCODE

Для взаимодействия с FPGA необходимо знать его IDCODE. Для FPGA в ячейке 233 можно узнать [тут](https://bsdl.info/details.htm?sid=156d619780a9b25688ca59b002289d77)

### Проверка

Из каталога `bscan/py`:

```bash
python -m unittest discover -v
```

Проверка линтером из корня `fpga-common-lib`:

```bash
ruff check bscan/py
```
