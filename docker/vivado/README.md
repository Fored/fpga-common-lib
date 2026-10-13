# Vivado 2025.1 build image

Образ для batch-сборки FPGA-проектов: Ubuntu 24.04 (amd64), Vivado 2025.1,
Git и Make. Установка Vivado выполняется при создании образа, а не при сборке
каждого проекта. Исходники проекта предоставляются при запуске, лицензии входят в образ.

## Подготовка установщика

Нужен полный Linux-установщик Vivado 2025.1, распакованный в отдельную папку
вне репозитория. В корне этой папки должен находиться исполняемый `xsetup`.
ISO можно предварительно смонтировать и скопировать его содержимое в эту папку.
Web installer для этого Dockerfile не подходит: образ создаётся без учётных
данных AMD и без скачивания компонентов через xsetup.

Конфигурация `install_config.txt` хранится рядом с Dockerfile. Она подготовлена
из файла, созданного штатной командой `xsetup -b ConfigGen`: выбраны Vivado ML
Enterprise, каталог `/opt/Xilinx` и поддержка Virtex-7 для проекта `2g_trx`.
Vitis Model Composer, DocNav, ярлыки и файловые ассоциации отключены.

Для других проектов включите нужные семейства в `Modules` этого файла или
создайте общий образ с несколькими семействами. Конфигурация подключается
отдельно при сборке; копировать её в папку установщика не требуется.

## Создание образа

Нужен Docker с Buildx/BuildKit и поддержкой именованных build contexts.
Положите один или несколько файлов с расширением `.lic` рядом с Dockerfile.
Имена произвольные: все файлы `*.lic` копируются в
`/opt/Xilinx/2025.1/Vivado/licenses/`, а `XILINXD_LICENSE_FILE` указывает на этот
каталог. Без файлов `.lic` сборка завершится ошибкой. Они исключены из Git,
но входят в готовый образ.

Из этой папки выполните, заменив путь на свою папку установщика:

```bash
docker buildx build --load --platform linux/amd64 \
  --build-context installer=/mnt/iso \
  -t vivado:2025.1 .
```

Команда установки внутри Dockerfile принимает Xilinx EULA и Third Party EULA.
Папка установщика подключается только на время установки. Итоговый образ
содержит весь каталог установки `/opt/Xilinx/2025.1/`, включая `Vivado`,
общие данные, библиотеки, `lnx64` и другие компоненты, созданные установщиком.
Внутри каталога версии ничего вручную не удаляется. Установщик и служебная
папка `/opt/Xilinx/.xinstall` в итоговый образ не входят; DocNav отключён
в конфигурации установки. В Vivado 2025.1 пути `Vivado/data`, `Vivado/tps`
и `Vivado/gnu` — ссылки на общие каталоги, поэтому одной папки `Vivado`
недостаточно для полного образа.
Для создания образа нужно место как для промежуточной установки, так и для
итогового образа; BuildKit также может хранить build cache.

Совместимость `libtinfo.so.5` обеспечивается библиотекой из Ubuntu 22.04.
Системная `libudev` Ubuntu 24.04 сохраняется. Графический интерфейс, драйверы
кабелей и ModelSim не входят в область применения этого образа.

## Проверка и запуск

```bash
docker run --rm vivado:2025.1 vivado -version
```

Из корня FPGA-проекта batch-сборка запускается так:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$(pwd),dst=/build" \
  vivado:2025.1 vivado -mode batch \
  -source fpga-common-lib/scripts/vivado/build.tcl \
  -tclargs project/my_project.xpr
```

`fpga-common-lib/scripts/vivado/build.tcl` — общий скрипт из библиотеки,
он не включён в образ. Замените `project/my_project.xpr` на путь к своему проекту.
Запуск от UID/GID текущего пользователя сохраняет владельца результатов
сборки. Для синтеза и implementation используется включённая в образ лицензия.
Успешный `vivado -version` проверяет запуск программы, но не лицензию или
успешность сборки FPGA.

## Документация

- [Поддерживаемые ОС Vivado 2025.1](https://docs.amd.com/r/2025.1-English/ug973-vivado-release-notes-install-license/Supported-Operating-Systems)
- [Генерация конфигурации установщика](https://docs.amd.com/r/2025.1-English/ug973-vivado-release-notes-install-license/Generate-a-Configuration-File)
- [Временные mounts при сборке Docker](https://docs.docker.com/build/building/best-practices/)
