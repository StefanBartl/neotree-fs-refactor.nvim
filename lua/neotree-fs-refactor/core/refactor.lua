---@module 'neotree-fs-refactor.core.refactor'
---@brief Core refactoring logic for updating file references
---@description
--- This module handles the actual refactoring of file references across
--- buffers and project files. It supports various languages and import patterns.

local scanner = require("neotree-fs-refactor.utils.scanner")
local path_utils = require("neotree-fs-refactor.utils.path")

local M = {}
local api, fn = vim.api, vim.fn
local str_fmt = string.format
local fnamemodify = fn.fnamemodify
local notify = require("neotree-fs-refactor.utils.notify")

---Get replacement patterns for specific filetype
---@param filetype string File type
---@return table|nil patterns List of pattern configurations
local function get_patterns_for_filetype(filetype)
	local patterns = {}

	if filetype == "lua" then
		-- Lua require patterns
		table.insert(patterns, {
			replacer = function(line, old_path, new_path)
				local old_module = path_utils.file_to_module(old_path)
				local new_module = path_utils.file_to_module(new_path)
            if not old_module or not new_module then
                notify.error("module is nil")
                    return nil
            end


            if old_module == "" or new_module == "" then
                return line
            end

				-- Escape special pattern characters
				local old_escaped = old_module:gsub("[%.%-%+%*%?%[%]%^%$%(%)%%]", "%%%1")

				-- Pattern 1: require("module")
				local pattern1 = "require%s*%(%s*[\"']" .. old_escaped .. "[\"']%s*%)"
				local replacement1 = 'require("' .. new_module .. '")'
				line = line:gsub(pattern1, replacement1)

				-- Pattern 2: require "module" (without parentheses)
				local pattern2 = "require%s+[\"']" .. old_escaped .. "[\"']"
				local replacement2 = 'require "' .. new_module .. '"'
				line = line:gsub(pattern2, replacement2)

				return line
			end,
		})
	elseif filetype:match("^typescript") or filetype:match("^javascript") then
		-- TypeScript/JavaScript import patterns
		table.insert(patterns, {
			replacer = function(line, old_path, new_path)
				local old_rel = path_utils.to_relative_import(old_path)
				local new_rel = path_utils.to_relative_import(new_path)

				if old_rel == "" or new_rel == "" then
					return line
				end

				-- Escape special pattern characters
				local old_escaped = old_rel:gsub("[%.%-%+%*%?%[%]%^%$%(%)%%/]", "%%%1")

				-- Pattern 1: from "path" or from 'path'
				for _, quote in ipairs({ '"', "'" }) do
					local pattern = "from%s+" .. quote .. "(" .. old_escaped .. ")" .. quote
					local replacement = "from " .. quote .. new_rel .. quote
					line = line:gsub(pattern, replacement)

					-- Pattern 2: import "path" or import 'path'
					local import_pattern = "import%s+" .. quote .. "(" .. old_escaped .. ")" .. quote
					local import_replacement = "import " .. quote .. new_rel .. quote
					line = line:gsub(import_pattern, import_replacement)
				end

				return line
			end,
		})
	elseif filetype == "python" then
		-- Python import patterns
		table.insert(patterns, {
			replacer = function(line, old_path, new_path)
				local old_module = path_utils.path_to_python_module(old_path)
				local new_module = path_utils.path_to_python_module(new_path)

				if old_module == "" or new_module == "" then
					return line
				end

				-- Escape special pattern characters
				local old_escaped = old_module:gsub("[%.%-%+%*%?%[%]%^%$%(%)%%]", "%%%1")

				-- Pattern 1: from X import Y
				local pattern1 = "from%s+" .. old_escaped .. "%s+import"
				local replacement1 = "from " .. new_module .. " import"
				line = line:gsub(pattern1, replacement1)

				-- Pattern 2: import X
				local pattern2 = "import%s+" .. old_escaped .. "([%s,])"
				local replacement2 = "import " .. new_module .. "%1"
				line = line:gsub(pattern2, replacement2)

				-- Pattern 3: import X (at end of line)
				local pattern3 = "import%s+" .. old_escaped .. "$"
				local replacement3 = "import " .. new_module
				line = line:gsub(pattern3, replacement3)

				return line
			end,
		})
	end

	return patterns
end

---Replace path references in a single line
---@param line string Line content
---@param old_path string Path to replace
---@param new_path string Replacement path
---@param filetype string File type for context
---@return string modified_line Line with replacements applied
local function replace_path_in_line(line, old_path, new_path, filetype)
  local patterns = get_patterns_for_filetype(filetype)

  -- Type guard: Ensure patterns is a table
  if not patterns or type(patterns) ~= "table" then
    notify.warn(string.format("No patterns found for filetype: %s", filetype))
    return line
  end

  local modified = line

  for _, pattern_info in ipairs(patterns) do
    local result = pattern_info.replacer(modified, old_path, new_path)
    if result ~= modified then
      modified = result
      -- Log for debugging
      notify.debug(string.format("[DEBUG] Replaced in line:\n  Old: %s\n  New: %s", line, modified))
    end
  end

  return modified
end

---Update all loaded buffers containing references
---@param old_path string Original path
---@param new_path string New path
---@param config Neotree.FSRefactor.Config Configuration
---@return table stats Statistics {count: number, lines: number}
local function update_buffers(old_path, new_path, config)
	local stats = { count = 0, lines = 0 }

	for _, bufnr in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_loaded(bufnr) and api.nvim_get_option_value("modifiable", { buf = bufnr }) then
			local buf_path = api.nvim_buf_get_name(bufnr)
			local ft = api.nvim_get_option_value("filetype", { buf = bufnr })

			-- Skip if filetype not in config
			if config.file_types[ft] and buf_path ~= "" then
				local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
				local changed_lines = {}
				local changes_made = false

				for i, line in ipairs(lines) do
					local new_line = replace_path_in_line(line, old_path, new_path, ft)
					if new_line ~= line then
						changed_lines[i] = new_line
						changes_made = true
						stats.lines = stats.lines + 1
					end
				end

				if changes_made then
					-- Apply changes
					for line_nr, new_content in pairs(changed_lines) do
						api.nvim_buf_set_lines(bufnr, line_nr - 1, line_nr, false, { new_content })
					end

					stats.count = stats.count + 1

					-- Auto-save if configured
					if config.auto_save then
						api.nvim_buf_call(bufnr, function()
							vim.cmd("silent! write")
						end)
					end
				end
			end
		end
	end

	return stats
end

---Update a file on disk
---@param file_path string Path to file
---@param old_path string Original path to replace
---@param new_path string New path
---@param config Neotree.FSRefactor.Config Configuration
---@return number lines_changed Number of lines changed
---@diagnostic disable-next-line: unused-local
local function update_file_on_disk(file_path, old_path, new_path, config)
	local ok, lines = pcall(function()
		local f = io.open(file_path, "r")
		if not f then
			return nil
		end
		local content = f:read("*all")
		f:close()
		return vim.split(content, "\n")
	end)

	if not ok or not lines then
		return 0
	end

	local ft = path_utils.get_filetype_from_extension(file_path)
	local changed_lines = {}
	local changes_made = false

	for i, line in ipairs(lines) do
		local new_line = replace_path_in_line(line, old_path, new_path, ft)
		if new_line ~= line then
			changed_lines[i] = new_line
			changes_made = true
		end
	end

	if changes_made then
		-- Apply changes
		for line_nr, new_content in pairs(changed_lines) do
			lines[line_nr] = new_content
		end

		-- Write back to file
		local write_ok = pcall(function()
			local f = io.open(file_path, "w")
			if f then
				f:write(table.concat(lines, "\n"))
				f:close()
			end
		end)

		if write_ok then
			return vim.tbl_count(changed_lines)
		end
	end

	return 0
end

---Update references when a file is renamed
---@param old_path string Original file path
---@param new_path string New file path
---@param config Neotree.FSRefactor.Config Plugin configuration
---@return boolean success Whether the operation succeeded
---@return Neotree.FSRefactor.Result|nil result Refactoring statistics
function M.rename_references(old_path, new_path, config)
	local result = {
		files_changed = 0,
		lines_changed = 0,
		buffers_updated = 0,
	}

	-- Normalize paths
	old_path = path_utils.normalize(old_path)
	new_path = path_utils.normalize(new_path)

	if old_path == new_path then
		return true, result
	end

	-- Debug logging
	local old_module = path_utils.file_to_module(old_path)
	local new_module = path_utils.file_to_module(new_path)

	notify.info(
		string.format(
			"Refactoring:\n  File: %s → %s\n  Module: %s → %s",
			vim.fn.fnamemodify(old_path, ":~:."),
			vim.fn.fnamemodify(new_path, ":~:."),
			old_module,
			new_module
		)
	)

	-- Step 1: Update open buffers first
	local buf_stats = update_buffers(old_path, new_path, config)
	result.buffers_updated = buf_stats.count
	result.lines_changed = result.lines_changed + buf_stats.lines

	-- Step 2: Scan and update project files
	local cwd = fn.getcwd()
	local files = scanner.find_files_with_references(cwd, old_path, config)

	notify.info(str_fmt("[neotree-fs-refactor] Found %d files with potential references", #files))

	for _, file_path in ipairs(files) do
		-- Skip if already open in buffer (already handled)
		local bufnr = fn.bufnr(file_path)
		if bufnr == -1 or not api.nvim_buf_is_loaded(bufnr) then
			local changed = update_file_on_disk(file_path, old_path, new_path, config)
			if changed > 0 then
				result.files_changed = result.files_changed + 1
				result.lines_changed = result.lines_changed + changed
				notify.debug(
					str_fmt("[neotree-fs-refactor] Updated: %s (%d lines)", fnamemodify(file_path, ":~:."), changed)
				)
			end
		end
	end

	return true, result
end

---Update references when a file is moved
---@param old_path string Original file path
---@param new_path string New file path
---@param config Neotree.FSRefactor.Config Plugin configuration
---@return boolean success Whether the operation succeeded
---@return Neotree.FSRefactor.Result|nil result Refactoring statistics
function M.move_references(old_path, new_path, config)
	-- File move is essentially the same as rename
	return M.rename_references(old_path, new_path, config)
end

---Handle references when a file is deleted
---@param deleted_path string Path to deleted file
---@param config Neotree.FSRefactor.Config Plugin configuration
---@return boolean success Whether the operation succeeded
---@return Neotree.FSRefactor.Result|nil result Refactoring statistics
function M.delete_references(deleted_path, config)
	local result = {
		files_changed = 0,
		lines_changed = 0,
		buffers_updated = 0,
	}

	deleted_path = path_utils.normalize(deleted_path)

	-- Find all references to deleted file
	local cwd = fn.getcwd()
	local files = scanner.find_files_with_references(cwd, deleted_path, config)

	if #files > 0 then
		notify.warn(
			str_fmt(
				"[neotree-fs-refactor] Warning: %d file(s) still reference deleted file: %s",
				#files,
				fnamemodify(deleted_path, ":~:.")
			)
		)
	end

	return true, result
end

return M
