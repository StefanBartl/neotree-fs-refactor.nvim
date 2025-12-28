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
  cache = {
    enabled = true,
    method = "async_lua",
    path = "/tmp/test_refactor_cache",
    cleanup_after_days = 7,
    incremental_updates = false,
  },
  refactor = {
    confirm_before_write = false,
    dry_run = false,
    show_picker = false,
  },
  ui = {
    log_level = "error",
    progress_notifications = false,
  },
})

print("Test environment initialized")
