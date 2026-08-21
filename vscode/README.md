
## Linting, code style

### VHDL

#### Для линтинга

Используй плагин для VSCode:

* [VHDL LS](https://marketplace.visualstudio.com/items?itemName=hbohlin.vhdl-ls)

#### Для форматирования

Для VHDL используется [vhdl-style-guide](https://github.com/jeremiah-c-leary/vhdl-style-guide)

Для автоформатирования поставить плагин выполнения команд при сохранении:

* [RunOnSave](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave)

Поставить vsg

```shell
sudo dnf install pipx
pipx install vsg
```

Add to .vscode/settings.json

```text
"[vhdl]": {
          "files.encoding": "utf8"
  },
"emeraldwalk.runonsave": {
      "commands": [
        {
          "match": "\\.vhd$|\\.vhdl$",
          "cmd": "echo '${file}' | xargs -I {} vsg -f \"{}\" --fix --configuration=.vhdl-style.yaml"
        }
      ]
  }
```

### System Verilog

Code style is based on [lowRISC style-guides](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md)

#### Для линтинга

Используй плагин для VSCode:

* [VerilogHDL](https://marketplace.visualstudio.com/items?itemName=mshr-h.VerilogHDL)
* [Verible](https://marketplace.visualstudio.com/items?itemName=CHIPSAlliance.verible)

Внутри плагина VerilogHDL используется [Verilator](https://verilator.org/guide/latest/install.html#package-manager-quick-install)

  ```shell
    sudo apt-get install verilator   # On Ubuntu
    sudo dnf install verilator verilator-devel # On Fedora
  ```

Add to .vscode/settings.json

```text
  "verilog.linting.linter": "verilator",
  "verilog.linting.verilator.arguments": "-I<Path to Vivado>/data/verilog/src/xeclib -F ./.verilator_args",
  "verilog.ctags.path": "/usr/bin/ctags"
  "verible.arguments": [
        "--rules=parameter-name-style=\"localparam_style:ALL_CAPS;parameter_style:ALL_CAPS\",line-length=\"length:120\"",
        "--column_limit=120"
    ],
  "[systemverilog]": {
      "editor.defaultFormatter": "chipsalliance.verible"
  },
```

#### Для форматирования

Для форматирования через pre-commit потребуется поставить [Verible](https://github.com/chipsalliance/verible)

* Download [Verible](https://github.com/chipsalliance/verible/releases)
* Unpack and add to PATH
