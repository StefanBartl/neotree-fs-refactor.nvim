---@module 'neotree-fs-refactor.neotree_integration'
---@brief Integration hooks for Neo-tree file operations
---@description
--- Provides hooks that Neo-tree can call after file/directory renames
--- to trigger automatic refactoring of require statements.

local logger = require("neotree-fs-refactor.utils.logger")

local M = {}

--- Hook to be called after Neo-tree renames a file or directory
---@param old_path string Old path (absolute)
---@param new_path string New path (absolute)
---@return nil
function M.on_rename(old_path, new_path)
  local main = require("neotree-fs-refactor")

  if not main.is_initialized() then
    logger.warn("Plugin not initialized, skipping refactor")
    return
  end

  -- Defer to avoid blocking Neo-tree UI
  vim.schedule(function()
    local refactor = require("neotree-fs-refactor.refactor")
    refactor.handle_rename(old_path, new_path)
  end)
end

--- Hook to be called after Neo-tree moves a file or directory
---@param old_path string Old path (absolute)
---@param new_path string New path (absolute)
---@return nil
function M.on_move(old_path, new_path)
  -- Move is essentially the same as rename for our purposes
  M.on_rename(old_path, new_path)
end

--- Setup Neo-tree integration
--- This should be called from Neo-tree's config
---@return nil
function M.setup_neotree()
  -- Check if Neo-tree is available
  local ok, _ = pcall(require, "neo-tree")
  if not ok then
    logger.debug("Neo-tree not found, skipping integration setup")
    return
  end

  logger.info("Setting up Neo-tree integration")

  -- We'll integrate via Neo-tree's event system
  -- This will be documented for users to add to their Neo-tree config
end

--- Get integration config for Neo-tree setup
---@return table Configuration snippet for Neo-tree
function M.get_neotree_config()
  return {
    event_handlers = {
      {
        event = "file_renamed",
        handler = function(args)
          M.on_rename(args.source, args.destination)
        end,
      },
      {
        event = "file_moved",
        handler = function(args)
          M.on_move(args.source, args.destination)
        end,
      },
    },
  }
end

return M
