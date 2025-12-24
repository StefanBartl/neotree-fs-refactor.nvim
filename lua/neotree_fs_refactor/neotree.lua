---@module 'neotree_fs_refactor.neotree'
---@brief Integration hooks for Neo-tree filesystem events
---@description
--- Provides event handlers for Neo-tree's file operations
--- (rename, move, delete) and triggers refactoring workflow.

local config = require("neotree_fs_refactor.config")
local orchestrator = require("neotree_fs_refactor.orchestrator")
local preview = require("neotree_fs_refactor.ui.preview")
local utils = require("neotree_fs_refactor.utils")
local notify = require("neotree_fs_refactor.utils.notify")

local M = {}

---Convert Neo-tree event to Neotree.FSRefactor.FSOperation
---@param event table Neo-tree event data
---@return Neotree.FSRefactor.FSOperation|nil operation
---@return string|nil error
local function event_to_operation(event)
  if type(event) ~= "table" then
    return nil, "Invalid event data"
  end

  -- Determine operation type
  local op_type = "rename" -- default

  if event.type then
    if event.type == "renamed" or event.type == "rename" then
      op_type = "rename"
    elseif event.type == "moved" or event.type == "move" then
      op_type = "move"
    elseif event.type == "deleted" or event.type == "delete" then
      op_type = "delete"
    end
  end

  -- Extract paths
  local old_path = event.before or event.old_path or event.source
  local new_path = event.after or event.new_path or event.destination

  if not old_path then
    return nil, "Missing source path in event"
  end

  -- Normalize paths
  old_path = utils.to_absolute(old_path)
  if not old_path then
    return nil, "Invalid source path"
  end

  if new_path then
    new_path = utils.to_absolute(new_path)
    if not new_path then
      return nil, "Invalid destination path"
    end
  end

  -- Determine if directory
  local is_dir = false
  if event.is_directory ~= nil then
    is_dir = event.is_directory
  else
    -- Try to detect from filesystem
    is_dir = utils.is_directory(old_path)
  end

  return {
    type = op_type,
    old_path = old_path,
    new_path = new_path,
    is_directory = is_dir,
    timestamp = os.time(),
  }, nil
end

---Handle file/directory renamed event
---@param event table Neo-tree event
---@return nil
function M.on_renamed(event)
  local operation, err = event_to_operation(event)
  if not operation then
    notify.error("Failed to parse rename event: " .. (err or "unknown error"))
        return
  end

  -- Create refactoring plan
  local plan, plan_err = orchestrator.create_plan(operation)
  if not plan then
    notify.error("Failed to create refactoring plan: " .. (plan_err or "unknown error"))
    return
  end

  -- Get plan summary
  local summary = orchestrator.get_plan_summary(plan)

  if summary.total_edits == 0 then
    local level = config.get_notify_level()
    if level <= vim.log.levels.INFO then
      notify.info("No references found to update")
    end
    return
  end

  -- Show preview or auto-apply
  if config.should_show_preview() and not config.should_auto_apply() then
    local ok, preview_err = preview.show_preview(plan, function(confirmed)
      if confirmed then
        plan.reviewed = true
        local result = orchestrator.execute_plan(plan, false)

        if not result.success then
          notify.error(
            string.format("Refactoring failed: %d errors", #result.errors)
          )
        end
      else
        notify.info("Refactoring cancelled")
      end
    end)

    if not ok then
      notify.error("Failed to show preview: " .. (preview_err or "unknown error"))
    end
  else
    -- Auto-apply without preview
    plan.reviewed = true
    local result = orchestrator.execute_plan(plan, true)

    if not result.success then
      notify.error(
        string.format("Refactoring failed: %d errors", #result.errors)
      )
    end
  end
end

---Handle file/directory moved event
---@param event table Neo-tree event
---@return nil
function M.on_moved(event)
  -- Move is essentially the same as rename
  M.on_renamed(event)
end

---Handle file/directory deleted event
---@param event table Neo-tree event
---@return nil
function M.on_deleted(event)
  local operation, err = event_to_operation(event)
  if not operation then
    notify.error("Failed to parse delete event: " .. (err or "unknown error"))
    return
  end

  -- For delete operations, we might want to search for broken references
  -- but not auto-fix them. Just notify the user.
  local level = config.get_notify_level()
  if level <= vim.log.levels.INFO then
    notify.info(
      string.format("File deleted: %s - references may need manual cleanup", operation.old_path)
    )
  end
end

---Register hooks with Neo-tree
---@return boolean success
---@return string|nil error
function M.register_hooks()
  -- Check if Neo-tree is available
  local ok, _ = pcall(require, "neo-tree")
  if not ok then
    return false, "Neo-tree not found"
  end

  -- Get Neo-tree events module
  local events_ok, events = pcall(require, "neo-tree.events")
  if not events_ok then
    return false, "Neo-tree events module not found"
  end

  -- Subscribe to events
  local subscriptions = {
    {
      event = events.FILE_RENAMED,
      handler = M.on_renamed,
    },
    {
      event = events.FILE_MOVED,
      handler = M.on_moved,
    },
    {
      event = events.FILE_DELETED,
      handler = M.on_deleted,
    },
  }

  for i = 1, #subscriptions do
    local sub = subscriptions[i]

    if sub.event then
      events.subscribe({
        event = sub.event,
        handler = sub.handler,
      })
    end
  end

  local level = config.get_notify_level()
  if level <= vim.log.levels.INFO then
    notify.info("Neo-tree refactoring hooks registered")
  end

  return true, nil
end

---Unregister all hooks (for cleanup/testing)
function M.unregister_hooks()
  local ok, _ = pcall(require, "neo-tree.events")
  if not ok then
    return
  end

  -- Neo-tree doesn't provide unsubscribe, so we'll just note this
  -- In practice, hooks will be replaced on next register
  local level = config.get_notify_level()
  if level <= vim.log.levels.DEBUG then
    notify.debug("Neo-tree hooks cleanup requested")
  end
end

return M
