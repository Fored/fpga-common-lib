
# Linting, code style

## VHDL

Используй плагин для VSCode:

* [VHDL LS](https://marketplace.visualstudio.com/items?itemName=hbohlin.vhdl-ls)

Весь код, который коммитится в репозитории, должен быть пропущен через автоформатер:

### Для VHDL используется [vhdl-style-guide](https://github.com/jeremiah-c-leary/vhdl-style-guide)

Для автоформатирования поставить плагин выполнения команд при сохранении:

* [RunOnSave](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave)

Поставить vsg

```shell
sudo dnf install pipx
pipx install vsg
```

Add to .vscode/settings.json

```text
"emeraldwalk.runonsave": {
      "commands": [
        {
          "match": "\\.vhd$|\\.vhdl$",
          "cmd": "echo '${file}' | xargs -I {} vsg -f \"{}\" --fix --configuration=.vhdl-style.yaml"
        }
      ]
  }
```