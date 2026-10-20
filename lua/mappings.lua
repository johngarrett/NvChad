require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

local function show_tree(git_only)
  local api = require "nvim-tree.api"
  local opts = api.config.global()
  local switching = opts.filters.git_clean ~= git_only
  if switching or (git_only and (not opts.filters.enable or not opts.git.enable)) then
    opts.filters.git_clean = git_only
    if git_only then
      opts.filters.enable = true
      opts.git.enable = true
    end
    require("nvim-tree").setup(opts)
    api.tree.open()
  elseif git_only then
    api.tree.open()
  else
    api.tree.toggle()
  end
end

map("n", "<C-n>", function()
  show_tree(false)
end, { desc = "Toggle full NvimTree" })

map("n", "<C-m>", function()
  show_tree(true)
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
