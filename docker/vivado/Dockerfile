# syntax=docker/dockerfile:1

# В Ubuntu 24.04 отсутствует libtinfo.so.5, которая по-прежнему нужна Vivado.
FROM ubuntu:22.04 AS legacy-libraries
RUN apt-get update \
    && apt-get install -y --no-install-recommends libtinfo5 \
    && rm -rf /var/lib/apt/lists/*

FROM ubuntu:24.04 AS base
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash ca-certificates git locales make procps unzip \
        libfontconfig1 libfreetype6 libglib2.0-0t64 libice6 libsm6 \
        libncurses6 libstdc++6 libtinfo6 libudev1 libuuid1 \
        libx11-6 libxext6 libxft2 libxi6 libxrender1 libxt6 libxtst6 libzstd1 zlib1g \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=legacy-libraries /lib/x86_64-linux-gnu/libtinfo.so.5* /usr/lib/x86_64-linux-gnu/
RUN ldconfig

FROM base AS install
# Именованный контекст BuildKit "installer": распакованный полный Linux-установщик.
# Конфигурация установки хранится рядом с Dockerfile.
# Установщик подключается временно и не копируется в слои образа.
RUN --mount=type=bind,from=installer,target=/installer \
    --mount=type=bind,source=install_config.txt,target=/tmp/install_config.txt \
    test -x /installer/xsetup \
    && grep -qx 'Destination=/opt/Xilinx' /tmp/install_config.txt \
    && /installer/xsetup -a XilinxEULA,3rdPartyEULA -b Install \
        -c /tmp/install_config.txt \
    && test -x /opt/Xilinx/2025.1/Vivado/bin/vivado

FROM base AS runtime
# Сохраняем весь каталог версии, включая lnx64 и общие зависимости Vivado.
# Установщик и служебные файлы вне каталога версии в итоговый образ не входят.
COPY --from=install /opt/Xilinx/2025.1/ /opt/Xilinx/2025.1/
# Лицензии с любыми именами; Vivado ищет файлы *.lic в указанном каталоге.
COPY --chmod=0644 *.lic /opt/Xilinx/2025.1/Vivado/licenses/
# Для доступа к файлам лицензий каталог должен разрешать проход обычному пользователю.
RUN chmod 0755 /opt/Xilinx/2025.1/Vivado/licenses
ENV XILINXD_LICENSE_FILE=/opt/Xilinx/2025.1/Vivado/licenses
ENV PATH="/opt/Xilinx/2025.1/Vivado/bin:${PATH}"
# Настройки записи пользовательских файлов и обхода падения libudev в контейнере.
ENV HOME=/tmp \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libudev.so.1
WORKDIR /build
# Проверяем наличие целей ссылок и запуск программы до сохранения образа.
RUN test -d /opt/Xilinx/2025.1/Vivado/data \
    && test -d /opt/Xilinx/2025.1/Vivado/tps \
    && test -d /opt/Xilinx/2025.1/Vivado/gnu \
    && vivado -version
# Стандартная команда оболочки обеспечивает совместимость с Docker executor GitLab.
CMD ["/bin/bash"]
