require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls" }
vim.lsp.enable(servers)

-- Arduino is custom because it needs project-aware compile database generation
-- before clangd can analyze sketches correctly.
require("configs.arduino").setup()

-- read :h vim.lsp.config for changing options of lsp servers
