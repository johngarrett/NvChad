require "nvchad.autocmds"

local ok, stl_utils = pcall(require, "nvchad.stl.utils")

if ok then
  -- NvChad hides lsp_msg on narrower windows by default. Keep it visible so
  -- Arduino setup progress always appears in the bottom statusline area.
  stl_utils.lsp_msg = function()
    return stl_utils.state.lsp_msg
  end
end
