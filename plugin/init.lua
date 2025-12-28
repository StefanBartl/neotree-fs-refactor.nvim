---@module 'neotree-fs-refactor'
---@brief Public API for neotree-fs-refactor plugin
---@description
--- Main entry point providing setup and public functions.

-- Forward to internal init module
---@diagnostic disable-next-line
local M = require("neotree-fs-refactor.init")

--- Manually trigger a refactor for renamed file/directory
---@param old_path string Old path
---@param new_path string New path
---@return nil
function M.refactor(old_path, new_path)
  local refactor = require("neotree-fs-refactor.refactor")
  refactor.handle_rename(old_path, new_path)
end

--- Manually trigger a full rescan of current directory
---@return nil
function M.rescan()
  local refactor = require("neotree-fs-refactor.refactor")
  refactor.rescan_directory()
end

--- Get Neo-tree integration config
---@return table Configuration for Neo-tree
function M.get_neotree_config()
  local integration = require("neotree-fs-refactor.neotree_integration")
  return integration.get_neotree_config()
end

--- Check if cache exists for current directory
---@return boolean True if cache exists
function M.has_cache()
  local cache = require("neotree-fs-refactor.cache")
  return cache.get_cache() ~= nil
end

--- Get cache statistics
---@return table|nil Cache stats or nil if no cache
function M.get_cache_stats()
  local cache = require("neotree-fs-refactor.cache")
  local current = cache.get_cache()

  if not current then
    return nil
  end

  local total_files = vim.tbl_count(current.entries or {})
  local total_requires = 0
  for _, entries in pairs(current.entries or {}) do
    total_requires = total_requires + #entries
  end

  return {
    cwd = current.cwd,
    total_files = total_files,
    total_requires = total_requires,
    last_updated = os.date("%Y-%m-%d %H:%M:%S", current.last_updated),
    last_accessed = os.date("%Y-%m-%d %H:%M:%S", current.last_accessed),
  }
end

--- User commands
vim.api.nvim_create_user_command("RefactorRescan", function()
  M.rescan()
end, {
  desc = "Rescan current directory for require statements",
})

vim.api.nvim_create_user_command("RefactorCacheStats", function()
  local stats = M.get_cache_stats()
  if stats then
    print(string.format([[
Cache Statistics:
  CWD: %s
  Files with requires: %d
  Total requires: %d
  Last updated: %s
  Last accessed: %s
]], stats.cwd, stats.total_files, stats.total_requires, stats.last_updated, stats.last_accessed))
  else
    print("No cache found for current directory")
  end
end, {
  desc = "Show cache statistics",
})

return M
