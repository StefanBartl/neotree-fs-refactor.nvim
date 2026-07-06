---@module 'neotree-fs-refactor.health'
---@brief :checkhealth neotree-fs-refactor

local M = {}

function M.check()
  vim.health.start("neotree-fs-refactor")

  -- Neovim version (vim.system() is used for the ripgrep scan path)
  local version = vim.version()
  if version.major == 0 and version.minor < 10 then
    vim.health.error("Neovim >= 0.10 is required (found " .. tostring(version) .. ")")
  else
    vim.health.ok("Neovim " .. tostring(version))
  end

  -- neo-tree.nvim
  local neo_tree_ok = pcall(require, "neo-tree")
  if neo_tree_ok then
    vim.health.ok("neo-tree.nvim is installed")
  else
    vim.health.error("neo-tree.nvim is not installed")
  end

  -- plenary.nvim (neo-tree's own dependency)
  local plenary_ok = pcall(require, "plenary")
  if plenary_ok then
    vim.health.ok("plenary.nvim is installed")
  else
    vim.health.warn("plenary.nvim is not installed (recommended)")
  end

  -- ripgrep: optional, enables the fast scan path; a pure-Lua directory walk
  -- is used automatically when it's missing, so this is informational only.
  if vim.fn.executable("rg") == 1 then
    vim.health.ok("ripgrep found (fast scan path)")
  else
    vim.health.info("ripgrep not found — falling back to a pure-Lua directory walk (slower on large projects)")
  end

  -- Configuration
  local config = require("neotree-fs-refactor.config")
  local cfg = config.get()

  local valid, err = config.validate()
  if not valid then
    vim.health.error("Config validation failed: " .. (err or "unknown"))
  else
    vim.health.ok("Config validated")
  end

  if cfg.enabled then
    vim.health.ok("Plugin is enabled")
  else
    vim.health.warn("Plugin is disabled in configuration")
  end

  vim.health.info(string.format("Auto-save: %s", tostring(cfg.auto_save)))
  vim.health.info(string.format("Max file size: %d bytes", cfg.max_file_size))
end

return M
