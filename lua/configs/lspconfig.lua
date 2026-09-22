require("nvchad.configs.lspconfig").defaults()

vim.lsp.config("astro", {
  cmd = { "bun", "x", "astro-ls", "--stdio" },
  filetypes = { "astro" },
  root_markers = { "astro.config.mjs", "astro.config.ts", "package.json" },
})

local servers = { "html", "cssls", "astro" }
vim.lsp.enable(servers)

-- Arduino is custom because it needs project-aware compile database generation
-- before clangd can analyze sketches correctly.
require("configs.arduino").setup()

-- read :h vim.lsp.config for changing options of lsp servers
