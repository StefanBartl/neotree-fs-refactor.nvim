---@module 'neotree-fs-refactor.utils.logger'
---@brief Centralized logging utility with level-based filtering
---@description
--- Provides a consistent logging interface with configurable log levels.
--- Supports debug, info, warn, and error levels with proper notifications.

local M = {}

---@alias LogLevel "debug"|"info"|"warn"|"error"

---@type table<LogLevel, integer>
local LOG_LEVELS = {
  debug = 0,
  info = 1,
  warn = 2,
  error = 3,
}

---@type LogLevel
M.current_level = "info"

---@type integer
M._current_level_num = LOG_LEVELS.info

--- Setup logger with specific log level
---@param level LogLevel The minimum log level to display
---@return nil
function M.setup(level)
  if not LOG_LEVELS[level] then
    vim.notify(
      string.format("[neotree-fs-refactor] Invalid log level: %s. Using 'info'.", level),
      vim.log.levels.WARN
    )
    level = "info"
  end
  M.current_level = level
  M._current_level_num = LOG_LEVELS[level]
end

--- Internal logging function
---@param level LogLevel Log level
---@param msg string Log message
---@param notify_level integer vim.log.levels constant
---@return nil
local function log(level, msg, notify_level)
  if LOG_LEVELS[level] >= M._current_level_num then
    local prefix = "[neotree-fs-refactor]"
    vim.notify(string.format("%s %s", prefix, msg), notify_level)
  end
end

--- Log debug message
---@param msg string Message to log
---@return nil
function M.debug(msg)
  log("debug", "DEBUG: " .. msg, vim.log.levels.DEBUG)
end

--- Log info message
---@param msg string Message to log
---@return nil
function M.info(msg)
  log("info", msg, vim.log.levels.INFO)
end

--- Log warning message
---@param msg string Message to log
---@return nil
function M.warn(msg)
  log("warn", "WARNING: " .. msg, vim.log.levels.WARN)
end

--- Log error message
---@param msg string Message to log
---@return nil
function M.error(msg)
  log("error", "ERROR: " .. msg, vim.log.levels.ERROR)
end

--- Log with custom format (for structured output)
---@param level LogLevel Log level
---@param format string Format string
---@param ... any Format arguments
---@return nil
function M.logf(level, format, ...)
  local msg = string.format(format, ...)
  if level == "debug" then
    M.debug(msg)
  elseif level == "info" then
    M.info(msg)
  elseif level == "warn" then
    M.warn(msg)
  elseif level == "error" then
    M.error(msg)
  end
end

return M
