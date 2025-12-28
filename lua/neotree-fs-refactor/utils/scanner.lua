---@module 'neotree-fs-refactor.utils.scanner'
---@brief File scanning utilities for finding references
---@description
--- Scans project files to find references to a given path.
--- Uses ripgrep if available, falls back to native Lua scanning.

local path_utils = require("neotree-fs-refactor.utils.path")

local M = {}
local fn = vim.fn
local glob = fn.glob
local fnamemodify = fn.fnamemodify
local list_extend = vim.list_extend
local tbl_insert = table.insert

---Check if ripgrep is available
---@return boolean available True if rg command exists
local function has_ripgrep()
  return fn.executable("rg") == 1
end

---Build search patterns for a target path
---@param target_path string Path to search for
---@return string[] patterns Regular expression patterns
local function build_search_patterns(target_path)
  local patterns = {}
  local normalized = path_utils.normalize(target_path)

  -- Lua module pattern
  local lua_module = path_utils.file_to_module(normalized)
  if lua_module ~= "" then
    tbl_insert(patterns, lua_module)
  end

  -- Relative path patterns (for TS/JS)
  local relative = path_utils.to_relative_import(normalized)
  if relative ~= "" then
    tbl_insert(patterns, relative)
  end

  -- Python module pattern
  local python_module = path_utils.path_to_python_module(normalized)
  if python_module ~= "" then
    tbl_insert(patterns, python_module)
  end

  -- Filename pattern (last resort)
  local filename = fnamemodify(normalized, ":t:r")
  if filename ~= "" then
    tbl_insert(patterns, filename)
  end

  return patterns
end

---Find files containing references using ripgrep
---@param cwd string Working directory
---@param target_path string Path to search for
---@param config Neotree.FSRefactor.Config Configuration
---@return string[] files List of file paths
local function find_with_ripgrep(cwd, target_path, config)
  local files = {}

  -- Build search patterns (these are the module names to search for)
  local patterns = build_search_patterns(target_path)
  if #patterns == 0 then
    return files
  end

  -- Build rg command with ignore patterns
  local ignore_args = {}
  for _, pattern in ipairs(config.ignore_patterns) do
    tbl_insert(ignore_args, "--glob")
    tbl_insert(ignore_args, "!" .. pattern)
  end

  -- Search for each pattern
  for _, search_pattern in ipairs(patterns) do
    -- Escape special regex characters for ripgrep
    -- local escaped_pattern = search_pattern:gsub("[%.%-%+%*%?%[%]%^%$%(%)%%]", "\\%1")
    search_pattern = search_pattern:gsub("[%.%-%+%*%?%[%]%^%$%(%)%%]", "\\%1")

    local cmd = list_extend({
      "rg",
      "--files-with-matches",
      "--no-heading",
      "--no-messages",
      "--color=never",
      "--fixed-strings", -- Use literal string matching (faster and safer)
      "--max-filesize=" .. config.max_file_size,
      search_pattern, -- Search for the literal module name
    }, ignore_args)

    -- Use vim.system for better async support
    local result = vim.system(cmd, {
      cwd = cwd,
      text = true
    }):wait()

    if result.code == 0 and result.stdout then
      local lines = vim.split(result.stdout, "\n", { plain = true, trimempty = true })
      for _, file in ipairs(lines) do
        if file ~= "" then
          local full_path = fnamemodify(cwd .. "/" .. file, ":p")
          -- Don't include the target file itself
          local target_normalized = path_utils.normalize(target_path)
          if full_path ~= target_normalized and not vim.tbl_contains(files, full_path) then
            tbl_insert(files, full_path)
          end
        end
      end
    end
  end

  return files
end

---Check if file should be ignored
---@param file_path string File path
---@param config Neotree.FSRefactor.Config Configuration
---@return boolean should_ignore True if file should be ignored
local function should_ignore(file_path, config)
  for _, pattern in ipairs(config.ignore_patterns) do
    -- Convert glob pattern to Lua pattern
    local lua_pattern = pattern:gsub("%*%*", ".*"):gsub("%*", "[^/]*"):gsub("%?", ".")
    if file_path:match(lua_pattern) then
      return true
    end
  end
  return false
end

---Check if file contains any of the patterns
---@param file_path string File path
---@param patterns string[] Patterns to search for
---@return boolean contains True if file contains at least one pattern
local function file_contains_patterns(file_path, patterns)
  local ok, content = pcall(function()
    local f = io.open(file_path, "r")
    if not f then return nil end
    local text = f:read("*all")
    f:close()
    return text
  end)

  if not ok or not content then
    return false
  end

  for _, pattern in ipairs(patterns) do
    if content:find(vim.pesc(pattern), 1, true) then
      return true
    end
  end

  return false
end



---Find files containing references using native Lua
---@param cwd string Working directory
---@param target_path string Path to search for
---@param config Neotree.FSRefactor.Config Configuration
---@return string[] files List of file paths
local function find_with_lua(cwd, target_path, config)
  local files = {}
  local patterns = build_search_patterns(target_path)

  if #patterns == 0 then
    return files
  end

  -- Get all Lua files in directory recursively
  local all_files = glob(cwd .. "/**/*.lua", false, true)

  -- Also check for TS/JS/Python files based on config
  for ft, enabled in pairs(config.file_types) do
    if enabled then
      if ft == "typescript" or ft == "typescriptreact" then
        list_extend(all_files, glob(cwd .. "/**/*.ts", false, true))
        list_extend(all_files, glob(cwd .. "/**/*.tsx", false, true))
      elseif ft == "javascript" or ft == "javascriptreact" then
        list_extend(all_files, glob(cwd .. "/**/*.js", false, true))
        list_extend(all_files, glob(cwd .. "/**/*.jsx", false, true))
      elseif ft == "python" then
        list_extend(all_files, glob(cwd .. "/**/*.py", false, true))
      end
    end
  end

  local target_normalized = path_utils.normalize(target_path)

  for _, file_path in ipairs(all_files) do
    -- Skip the target file itself
    local file_normalized = fnamemodify(file_path, ":p")
    if file_normalized ~= target_normalized then
      -- Skip if matches ignore patterns
      if not should_ignore(file_path, config) then
        -- Check file size
        local stat = vim.loop.fs_stat(file_path)
        if stat and stat.type == "file" and stat.size <= config.max_file_size then
          -- Check if file contains any pattern
          if file_contains_patterns(file_path, patterns) then
            tbl_insert(files, file_normalized)
          end
        end
      end
    end
  end

  return files
end

---Find all files in project containing references to target path
---@param cwd string Current working directory
---@param target_path string Path to search for
---@param config Neotree.FSRefactor.Config Configuration
---@return string[] files List of file paths containing references
function M.find_files_with_references(cwd, target_path, config)
  if has_ripgrep() then
    return find_with_ripgrep(cwd, target_path, config)
  else
    return find_with_lua(cwd, target_path, config)
  end
end

return M
