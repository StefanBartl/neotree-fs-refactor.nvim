---@module 'neotree-fs-refactor.utils.notify'
---Notification helper that prefixes all messages with a fixed plugin tag

local M = {}

local notify, levels = vim.notify, vim.log.levels

-- Constant prefix for all notifications
local PREFIX = "[neotree-fs-refactor] "

---Notify with a fixed prefix, mirroring notify behavior
---@param msg string Notification message
---@param level? integer Log level (levels.*)
---@param opts? table Additional notify options
function M.notify(msg, level, opts)
  -- Ensure message is always a string
  if type(msg) ~= "string" then
    msg = tostring(msg)
  end

  -- Default values, matching notify semantics
  level = level or levels.INFO
  opts = opts or {}

  -- Prepend prefix exactly once
  notify(PREFIX .. msg, level, opts)
end

---Shorthand helpers for common log levels

---@param msg string
---@param opts? table
function M.info(msg, opts)
  M.notify(msg, levels.INFO, opts)
end

---@param msg string
---@param opts? table
function M.warn(msg, opts)
  M.notify(msg, levels.WARN, opts)
end

---@param msg string
---@param opts? table
function M.error(msg, opts)
  M.notify(msg, levels.ERROR, opts)
end

---@param msg string
---@param opts? table
function M.debug(msg, opts)
  M.notify(msg, levels.DEBUG, opts)
end

return M

