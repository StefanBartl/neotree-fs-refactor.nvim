-- Minimal init for testing

-- Add plugin to runtimepath
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h")
vim.opt.runtimepath:append(plugin_dir)

-- Add plenary
local plenary_dir = vim.fn.expand("~/.local/share/nvim/site/pack/vendor/start/plenary.nvim")
vim.opt.runtimepath:append(plenary_dir)

-- Basic settings
vim.opt.swapfile = false
vim.opt.backup = false

-- Initialize plugin with test config
---@diagnostic disable-next-line
require("neotree-fs-refactor").setup({
  notify_on_refactor = false,
  debounce_ms = 0,
})

print("Test environment initialized")
