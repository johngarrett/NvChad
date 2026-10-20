require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<C-m>", function()
  local api = require "nvim-tree.api"
  local opts = api.config.global()
  opts.filters.enable = true
  opts.filters.git_clean = true
  opts.git.enable = true
  require("nvim-tree").setup(opts)
  api.tree.open()
end, { desc = "Show Git changed files in NvimTree" })

map("n", "<leader>dv", "<cmd>DiffviewOpen<CR>", { desc = "Open Diffview" })
map("n", "<leader>dc", "<cmd>DiffviewClose<CR>", { desc = "Close Diffview" })

map("n", "<leader>gd", "<cmd>Telescope git_status<CR>", { desc = "Find Git dirty files" })

map("n", "<leader>fs", function()
  require("telescope.builtin").find_files {
    prompt_title = "Astro Files",
    find_command = { "rg", "--files", "--glob", "*.astro" },
  }
end, { desc = "Find Astro files" })

map("n", "<leader>ft", function()
  require("telescope.builtin").find_files {
      prompt_title = "TypeScript Files",
      find_command = {
        "rg",
        "--files",
        "--glob",
        "*.ts",
        "--glob",
        "*.tsx",
      },
  }
end, { desc = "Find TypeScript files" })
