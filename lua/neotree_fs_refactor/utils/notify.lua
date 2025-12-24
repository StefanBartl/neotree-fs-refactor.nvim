---@module 'neotree_fs_refactor.utils.notify'
---Notification helper that prefixes all messages with a fixed plugin tag

local M = {}

-- Constant prefix for all notifications
local PREFIX = "[neotree-fs-refactor] "

---Notify with a fixed prefix, mirroring vim.notify behavior
---@param msg string Notification message
---@param level? integer Log level (vim.log.levels.*)
---@param opts? table Additional vim.notify options
function M.notify(msg, level, opts)
  if type(msg) ~= "string" then
    msg = tostring(msg)
  end

  level = level or vim.log.levels.INFO
  opts = opts or {}

  vim.notify(PREFIX .. msg, level, opts)
end

---Shorthand helpers for common log levels

---@param msg string
---@param opts? table
function M.info(msg, opts)
  M.notify(PREFIX .. msg, vim.log.levels.INFO, opts)
end

---@param msg string
---@param opts? table
function M.warn(msg, opts)
  M.notify(PREFIX .. msg, vim.log.levels.WARN, opts)
end

---@param msg string
---@param opts? table
function M.error(msg, opts)
  M.notify(PREFIX .. msg, vim.log.levels.ERROR, opts)
end

---@param msg string
---@param opts? table
function M.debug(msg, opts)
  M.notify(PREFIX .. msg, vim.log.levels.DEBUG, opts)
end

return M

