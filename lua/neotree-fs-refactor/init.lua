---@module 'neotree-fs-refactor'
---@brief Entry point for neotree-fs-refactor.nvim plugin
---@description
--- This plugin automatically refactors file/folder references in your codebase
--- when files are renamed, moved, or deleted in neo-tree.
---
--- Key features:
--- - Listens to neo-tree file operations (rename, move, delete)
--- - Scans open buffers and project files for references
--- - Updates require()/import statements for Lua, Python, TypeScript, JavaScript
--- - Warns about remaining references when a file is deleted

local notify = require("neotree-fs-refactor.utils.notify")
local config = require("neotree-fs-refactor.config")

local M = {}

local str_fmt = string.format

---Setup function for the plugin
---@param opts Neotree.FSRefactor.Config|nil User configuration
---@return nil
function M.setup(opts)
  M.config = config.setup(opts)

  if not M.config.enabled then
    return
  end

  local valid, err = config.validate()
  if not valid then
    notify.error(str_fmt("Invalid configuration: %s", err))
    return
  end

  -- Verify neo-tree is installed
  local neo_tree_ok = pcall(require, "neo-tree")
  if not neo_tree_ok then
    notify.error("neo-tree.nvim is required but not installed")
    return
  end

  -- Load core modules
  local ok, load_err = pcall(function()
    require("neotree-fs-refactor.core.event_handlers").setup(M.config)
  end)

  if not ok then
    notify.error(str_fmt("Setup failed: %s", load_err))
    return
  end

  notify.info("Plugin loaded successfully")
end

--- Manually trigger a refactor for a renamed/moved file or directory.
--- Neo-tree renames already trigger this automatically via
--- core.event_handlers; this is for programmatic/other-trigger use.
---@param old_path string Old path (absolute)
---@param new_path string New path (absolute)
---@return nil
function M.refactor(old_path, new_path)
  require("neotree-fs-refactor.core.refactor").rename_references(old_path, new_path, config.get())
end

---Check plugin health — same checks as `:checkhealth neotree-fs-refactor`.
---@return nil
function M.check()
  require("neotree-fs-refactor.health").check()
end

return M
