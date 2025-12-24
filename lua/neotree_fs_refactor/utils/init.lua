---@module 'neotree_fs_refactor.utils'
---@brief Utility functions for path operations and validation
---@description
--- Collection of pure utility functions for path manipulation,
--- validation, and filesystem operations.

local notify = require("neotree_fs_refactor.utils.notify")

local M = {}

local uv, fn = vim.loop, vim.fn


---Normalize path separators to forward slashes
---@param path string Input path
---@return string # Normalized path
function M.normalize_path(path)
	if type(path) ~= "string" then
		return ""
	end

	return (path:gsub("\\", "/"))
end

---Convert path to absolute path
---@param path string Input path (relative or absolute)
---@return string|nil # Absolute path or nil on error
function M.to_absolute(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	local success, result = pcall(fn.fnamemodify, path, ":p")
	if not success then
		return nil
	end

	return M.normalize_path(result)
end

---Check if path exists in filesystem
---@param path string Path to check
---@return boolean
function M.path_exists(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local stat = uv.fs_stat(path)
	return stat ~= nil
end

---Check if path is a directory
---@param path string Path to check
---@return boolean
function M.is_directory(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local stat = uv.fs_stat(path)
	if not stat then
		return false
	end

	return stat.type == "directory"
end

---Get file size in kilobytes
---@param path string File path
---@return integer|nil # Size in KB or nil on error
function M.get_file_size_kb(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	local stat = uv.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return nil
	end

	return math.ceil(stat.size / 1024)
end

---Calculate relative path from base to target
---@param from string Base path
---@param to string Target path
---@return string|nil # Relative path or nil if not possible
function M.relative_path(from, to)
	if type(from) ~= "string" or type(to) ~= "string" then
		return nil
	end

	from = M.normalize_path(from)
	to = M.normalize_path(to)

	-- Split paths into components
	local from_parts = vim.split(from, "/", { plain = true })
	local to_parts = vim.split(to, "/", { plain = true })

	-- Find common prefix length
	local common = 0
	local min_len = math.min(#from_parts, #to_parts)

	for i = 1, min_len do
		if from_parts[i] == to_parts[i] then
			common = i
		else
			break
		end
	end

	-- Build relative path
	local result = {}

	-- Add "../" for each remaining from_parts
	for _ = common + 1, #from_parts do
		result[#result + 1] = ".."
	end

	-- Add remaining to_parts
	for i = common + 1, #to_parts do
		result[#result + 1] = to_parts[i]
	end

	if #result == 0 then
		return "."
	end

	return table.concat(result, "/")
end

---Extract directory path from file path
---@param path string File path
---@return string # Directory path
function M.dirname(path)
	if type(path) ~= "string" or path == "" then
		return ""
	end

	path = M.normalize_path(path)
	local parts = vim.split(path, "/", { plain = true })

	if #parts <= 1 then
		return "."
	end

	table.remove(parts)
	return table.concat(parts, "/")
end

---Extract filename from path
---@param path string File path
---@return string # Filename
function M.basename(path)
	if type(path) ~= "string" or path == "" then
		return ""
	end

	path = M.normalize_path(path)
	local parts = vim.split(path, "/", { plain = true })
	return parts[#parts] or ""
end

---Check if path matches any of the ignore patterns
---@param path string Path to check
---@param patterns string[] Ignore patterns (supports wildcards)
---@return boolean
function M.should_ignore(path, patterns)
	if type(path) ~= "string" or path == "" then
		return true
	end

	if type(patterns) ~= "table" then
		return false
	end

	path = M.normalize_path(path)

	for i = 1, #patterns do
		local pattern = patterns[i]
		if type(pattern) == "string" then
			-- Simple substring match for now
			if path:find(pattern, 1, true) then
				return true
			end
		end
	end

	return false
end

---Escape string for use in Lua pattern matching
---@param str string String to escape
---@return string # Escaped string
function M.escape_pattern(str)
	if type(str) ~= "string" then
		return ""
	end

	-- Escape magic characters in Lua patterns
	local magic_chars = "([%%.%+%-%%%[%]%(%)%$%^%*%?])"
	return (str:gsub(magic_chars, "%%%1"))
end

---Check if buffer is valid and loaded
---@param buf integer Buffer handle
---@return boolean
function M.is_valid_buffer(buf)
	if type(buf) ~= "number" then
		return false
	end

	return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)
end

---Check if window is valid
---@param win integer Window handle
---@return boolean
function M.is_valid_window(win)
	if type(win) ~= "number" then
		return false
	end

	return vim.api.nvim_win_is_valid(win)
end

---Safely get buffer lines
---@param buf integer Buffer handle
---@param start integer Start line (0-indexed)
---@param end_ integer End line (0-indexed, exclusive)
---@return string[]|nil # Lines or nil on error
function M.get_buf_lines(buf, start, end_)
	if not M.is_valid_buffer(buf) then
		return nil
	end

	local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, start, end_, false)
	if not ok then
		return nil
	end

	return lines
end

---Safely set buffer lines
---@param buf integer Buffer handle
---@param start integer Start line (0-indexed)
---@param end_ integer End line (0-indexed, exclusive)
---@param lines string[] Lines to set
---@return boolean # Success
function M.set_buf_lines(buf, start, end_, lines)
	if not M.is_valid_buffer(buf) then
		return false
	end

	if type(lines) ~= "table" then
		return false
	end

	local ok = pcall(vim.api.nvim_buf_set_lines, buf, start, end_, false, lines)
	return ok == true
end

---Debounce function execution
---@param debounce_fn function Function to debounce
---@param delay integer Delay in milliseconds
---@return function|nil # Debounced function
---@diagnostic disable-next-line: unused-local -- AUDIT:
function M.debounce(debounce_fn, delay)
	local timer = nil

	return function(...)
		local args = { ... }

		if timer then
			timer:stop()
			timer:close()
		end

		timer = uv.new_timer()
		if not timer then
			notify.error("timer is nil")
			return
		end

        ---@cast timer uv.uv_timer_t

		timer:start(delay, 0, function()
			timer:stop()
			timer:close()
			timer = nil

			vim.schedule(function()
				fn(unpack(args))
			end)
		end)
	end
end

---Create a simple deep copy of a table
---@param tbl table Table to copy
---@return table # Copied table
function M.deep_copy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end

	local copy = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			copy[k] = M.deep_copy(v)
		else
			copy[k] = v
		end
	end

	return copy
end

---Merge two tables (second overwrites first)
---@param t1 table First table
---@param t2 table Second table
---@return table # Merged table
function M.merge_tables(t1, t2)
	local result = M.deep_copy(t1)

	for k, v in pairs(t2) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = M.merge_tables(result[k], v)
		else
			result[k] = v
		end
	end

	return result
end

return M
