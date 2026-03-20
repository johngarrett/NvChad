# Arduino LSP setup

This config uses `arduino-cli` to generate a compile database and runs `clangd` directly for Arduino projects.

It does not use `arduino-language-server`.

## What it does

- detects Arduino projects from `sketch.yaml`, `arduino-cli.yaml`, or a nearby `.ino`
- generates `.arduino-lsp/compile_commands.json`
- remaps Arduino's generated sketch commands so `clangd` works on real files like `src.ino`
- starts `clangd` asynchronously
- shows loading progress in NvChad's bottom statusline area

## Requirements

- `clangd`
- `arduino-cli`
- installed board core and libraries for your project
- board FQBN from `sketch.yaml` or `ARDUINO_FQBN`

This config prefers `arduino-cli` in this order:

- project-local `.tools/bin/arduino-cli`
- Arduino IDE bundled CLI
- `arduino-cli` from `PATH`

## Project files

Recommended layout:

```text
arduino-cli.yaml
src/
  sketch.yaml
  src.ino
```

Example `sketch.yaml`:

```yaml
default_fqbn: esp32:esp32:esp32
```

If you do not want to store `sketch.yaml`, use:

```sh
export ARDUINO_FQBN=esp32:esp32:esp32
```

Opening a sketch generates `.arduino-lsp/` locally. That directory is editor/build metadata and can be regenerated.

## Verify

Open the sketch and run:

```vim
:LspInfo
```

You should see `arduino_clangd`.

You should also see a short loading message in the bottom bar while the compile database is generated.

## Relevant files

- [`lua/configs/arduino.lua`](/Users/garrepi/.config/nvim/lua/configs/arduino.lua)
- [`lua/configs/lspconfig.lua`](/Users/garrepi/.config/nvim/lua/configs/lspconfig.lua)
- [`lua/chadrc.lua`](/Users/garrepi/.config/nvim/lua/chadrc.lua)
- [`lua/autocmds.lua`](/Users/garrepi/.config/nvim/lua/autocmds.lua)
