---@module 'plugin.neotree_fs_refactor'
---@brief Plugin specification for neotree-fs-refactor
---@description
--- This file is loaded automatically by Neovim when the plugin is installed.
--- It ensures the plugin is loaded only once and provides lazy loading support.

local api = vim.api

-- Prevent loading the plugin twice
if vim.g.loaded_neotree_fs_refactor then
  return
end
vim.g.loaded_neotree_fs_refactor = 1

-- Only load if Neovim version is sufficient
if vim.fn.has("nvim-0.9.0") ~= 1 then
  vim.notify(
    "neotree-fs-refactor requires Neovim >= 0.9.0",
    vim.log.levels.ERROR
  )
  return
end

-- Register health check
api.nvim_create_user_command("NeotreeRefactorHealth", function()
  vim.cmd("checkhealth neotree-fs-refactor")
end, {
  desc = "Check neotree-fs-refactor plugin health",
})

-- Create autocommand group for plugin
local augroup = api.nvim_create_augroup("NeotreeRefactor", { clear = true })

-- Lazy load on Neo-tree availability
api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = "NeoTreeInit",
  once = true,
  callback = function()
    -- Plugin will be initialized via setup() call from user config
    -- This just ensures it's available when Neo-tree is ready
  end,
  desc = "Initialize neotree-fs-refactor when Neo-tree is ready",
})
