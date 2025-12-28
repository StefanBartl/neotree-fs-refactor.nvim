---@module 'neotree-fs-refactor.utils.helpers'
---@brief General helper utilities
---@description
--- Provides notification helpers and other utility functions.

local notify = require("neotree-fs-refactor.utils.notify")

local M = {}

local str_fmt = string.format

---Notify user about refactoring results
---@param operation string Operation type ("rename", "move", "delete")
---@param old_path string Original path
---@param new_path string|nil New path (nil for delete)
---@param result table Result statistics
---@return nil
function M.notify_refactor_result(operation, old_path, new_path, result)
  local old_name = vim.fn.fnamemodify(old_path, ":~:.")
  local new_name = new_path and vim.fn.fnamemodify(new_path, ":~:.") or nil

  local message
  if operation == "rename" or operation == "move" then
    if result.files_changed > 0 or result.buffers_updated > 0 then
      message = str_fmt(
        "[neotree-fs-refactor] %s → %s\n" ..
        "✓ Buffers updated: %d\n" ..
        "✓ Files changed: %d\n" ..
        "✓ Lines modified: %d",
        old_name,
        new_name,
        result.buffers_updated,
        result.files_changed,
        result.lines_changed
      )
    else
      message = str_fmt(
        "[neotree-fs-refactor] %s → %s\nℹ No references found",
        old_name,
        new_name
      )
    end
  elseif operation == "delete" then
    message = str_fmt(
      "[neotree-fs-refactor] Deleted: %s\nℹ Check for broken references",
      old_name
    )
  else
    message = str_fmt("[neotree-fs-refactor] Unknown operation: %s", operation)
  end

  vim.notify(message, vim.log.levels.INFO)
end

---Check if a string is empty or nil
---@param str string|nil String to check
---@return boolean is_empty True if string is nil or empty
function M.is_empty(str)
  return str == nil or str == ""
end

---Deep copy a table
---@param tbl table Table to copy
---@return table copy Deep copy of the table
function M.deep_copy(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end

  local copy = {}
  for key, value in pairs(tbl) do
    copy[M.deep_copy(key)] = M.deep_copy(value)
  end

  return setmetatable(copy, getmetatable(tbl))
end

---Check if table contains value
---@param tbl table Table to search
---@param value any Value to find
---@return boolean contains True if value is in table
function M.contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

---Filter table by predicate function
---@param tbl table Table to filter
---@param predicate function Predicate function
---@return table filtered Filtered table
function M.filter(tbl, predicate)
  local filtered = {}
  for _, value in ipairs(tbl) do
    if predicate(value) then
      table.insert(filtered, value)
    end
  end
  return filtered
end

---Map table values using transform function
---@param tbl table Table to map
---@param transform function Transform function
---@return table mapped Mapped table
function M.map(tbl, transform)
  local mapped = {}
  for _, value in ipairs(tbl) do
    table.insert(mapped, transform(value))
  end
  return mapped
end

---Debounce a function call
---@param fn function Function to debounce
---@param delay number Delay in milliseconds
---@return function debounced Debounced function
function M.debounce(fn, delay)
  local timer = nil

  return function(...)
    local args = { ... }

    if timer then
      timer:stop()
      timer:close()
    end

    timer = vim.loop.new_timer()
    if not timer then
        notify.warn("timer is nil")
        return nil
    end

    ---@cast timer uv.uv_timer_t

    timer:start(delay, 0, vim.schedule_wrap(function()
      fn(unpack(args))
      timer:stop()
      timer:close()
      timer = nil
    end))
  end
end

---Escape string for use in Lua pattern
---@param str string String to escape
---@return string escaped Escaped string
function M.escape_pattern(str)
  return vim.pesc(str)
end

---Trim whitespace from string
---@param str string String to trim
---@return string trimmed Trimmed string
function M.trim(str)
  return str:match("^%s*(.-)%s*$")
end

---Split string by delimiter
---@param str string String to split
---@param delimiter string Delimiter
---@return string[] parts Split parts
function M.split(str, delimiter)
  local parts = {}
  local pattern = str_fmt("([^%s]+)", delimiter)

  for part in str:gmatch(pattern) do
    table.insert(parts, part)
  end

  return parts
end

return M
