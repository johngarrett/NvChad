require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<leader>dv", "<cmd>DiffviewOpen<CR>", { desc = "Open Diffview" })
map("n", "<leader>dc", "<cmd>DiffviewClose<CR>", { desc = "Close Diffview" })

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
