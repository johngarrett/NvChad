require("nvchad.configs.lspconfig").defaults()

vim.lsp.config("astro", {
  cmd = { "bun", "x", "astro-ls", "--stdio" },
  filetypes = { "astro" },
  root_markers = { "astro.config.mjs", "astro.config.ts", "package.json" },
})

local servers = { "html", "cssls", "astro" }
vim.lsp.enable(servers)

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.keymap.set("n", "<leader>gr", function()
      require("telescope.builtin").lsp_references()
    end, { buffer = args.buf, desc = "LSP find references" })
  end,
})

-- Arduino is custom because it needs project-aware compile database generation
-- before clangd can analyze sketches correctly.
require("configs.arduino").setup()

-- read :h vim.lsp.config for changing options of lsp servers
