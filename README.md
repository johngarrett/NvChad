**This repo is supposed to be used as config by NvChad users!**

- The main nvchad repo (NvChad/NvChad) is used as a plugin by this repo.
- So you just import its modules , like `require "nvchad.options" , require "nvchad.mappings"`
- So you can delete the .git from this repo ( when you clone it locally ) or fork it :)

# Credits

1) Lazyvim starter https://github.com/LazyVim/starter as nvchad's starter was inspired by Lazyvim's . It made a lot of things easier!

# Extra setup notes

- [Arduino LSP setup](./ARDUINO_SETUP.md)

The Arduino setup in this repo uses `arduino-cli` + `clangd` directly, not `arduino-language-server`.

## TypeScript HTML tagged templates

The `html` tagged template used by the personal website is highlighted as HTML
inside TypeScript files. The Tree-sitter injection is defined in
[`after/queries/typescript/injections.scm`](after/queries/typescript/injections.scm),
and the Neovim plugin configuration ensures the `html` and `typescript` parsers
are installed.

`nvim-treesitter` builds parsers locally for the current machine, so do not
commit parser binaries. It requires `tree-sitter-cli` on `PATH`; the parent
dotfiles setup installs it on macOS, Debian/Ubuntu, and Arch. For a standalone
installation, install `tree-sitter-cli`, then restart Neovim (or run
`:TSInstall typescript html`).
