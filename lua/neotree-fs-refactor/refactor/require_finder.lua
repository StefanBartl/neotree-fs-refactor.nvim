---@module 'neotree-fs-refactor.refactor.require_finder'
---@brief Find and update require() statements in files
---@description
--- Provides functionality to find require statements that need updating
--- when files or directories are renamed/moved.

local M = {}

local logger = require("neotree-fs-refactor.utils.logger")
local path_util = require("neotree-fs-refactor.utils.path")

---@class RequireChange
---@field file string Absolute file path
---@field line integer Line number (hint, may change)
---@field old_require string Old require path
---@field new_require string New require path
---@field old_line_content string|nil Original line content
---@field new_line_content string|nil Updated line content

--- Require patterns with capture groups
---@type table<string, {pattern: string, replacement: string}>
local REQUIRE_PATTERNS_WITH_REPLACEMENT = {
  {
    pattern = '(require%s*%(%s*["\'])([^"\']+)(["\']%s*%))',
    replacement = '%1%s%3', -- %s will be replaced with new module path
  },
  {
    pattern = '(require%s*["\'])([^"\']+)(["\'])',
    replacement = '%1%s%3',
  },
}

--- Find all files that require a specific module
---@param old_module_path string Old module path (e.g., "testfs.rem")
---@param new_module_path string New module path (e.g., "testfs.remolus")
---@return RequireChange[] List of changes to make
function M.find_require_changes(old_module_path, new_module_path)
  local cache = require("neotree-fs-refactor.cache")
  local current_cache = cache.get_cache()

  local changes = {}

  if not current_cache then
    logger.warn("No cache available, falling back to ripgrep")
    return M.find_require_changes_ripgrep(old_module_path, new_module_path)
  end

  -- Search cache for matching requires
  for file, entries in pairs(current_cache.entries or {}) do
    for _, entry in ipairs(entries) do
      local req_path = entry.require_path

      -- Check if this require matches or is a submodule
      local matches = false
      local new_req_path = nil

      if req_path == old_module_path then
        -- Exact match
        matches = true
        new_req_path = new_module_path
      elseif req_path:find("^" .. vim.pesc(old_module_path) .. "%.") then
        -- Submodule (e.g., "testfs.rem.da" when renaming "testfs.rem")
        matches = true
        local suffix = req_path:sub(#old_module_path + 2) -- +2 for the dot
        new_req_path = new_module_path .. "." .. suffix
      end

      if matches and new_req_path then
        changes[#changes + 1] = {
          file = file,
          line = entry.line,
          old_require = req_path,
          new_require = new_req_path,
        }
      end
    end
  end

  logger.info(string.format("Found %d require(s) to update", #changes))
  return changes
end

--- Verify and update line content for a change
---@param change RequireChange Change to verify
---@return boolean Success (true if line found and updated)
function M.verify_and_update_change(change)
  -- Read file
  local ok, lines = pcall(vim.fn.readfile, change.file)
  if not ok or not lines then
    logger.warn(string.format("Failed to read file: %s", change.file))
    return false
  end

  -- Search around the hint line number
  local search_start = math.max(1, change.line - 5)
  local search_end = math.min(#lines, change.line + 5)

  for i = search_start, search_end do
    local line = lines[i]

    -- Try to find and replace the require
    for _, pattern_info in ipairs(REQUIRE_PATTERNS_WITH_REPLACEMENT) do
      local before, module, after = line:match(pattern_info.pattern)

      if module and module == change.old_require then
        -- Found the require, update it
        change.line = i -- Update to actual line number
        change.old_line_content = line
        change.new_line_content = before .. change.new_require .. after

        logger.debug(string.format(
          "Verified require in %s:%d\n  Old: %s\n  New: %s",
          change.file, i, change.old_require, change.new_require
        ))
        return true
      end
    end
  end

  -- Not found
  logger.warn(string.format(
    "Could not find require '%s' in %s (searched lines %d-%d)",
    change.old_require, change.file, search_start, search_end
  ))
  return false
end

--- Fallback: Use ripgrep to find requires
---@param old_module_path string Old module path
---@param new_module_path string New module path
---@return RequireChange[] List of changes
function M.find_require_changes_ripgrep(old_module_path, new_module_path)
  -- Check if ripgrep is available
  if vim.fn.executable("rg") == 0 then
    logger.error("Ripgrep not found and no cache available")
    return {}
  end

  local cwd = vim.fn.getcwd()
  local pattern = string.format([[require.*["\']%s]], old_module_path)
  local cmd = string.format(
    'rg --vimgrep --type lua "%s" "%s"',
    pattern,
    cwd
  )

  logger.info("Using ripgrep fallback: " .. cmd)

  local output = vim.fn.systemlist(cmd)
  local changes = {}

  for _, line in ipairs(output) do
    -- Parse ripgrep output: "file:line:col:content"
    local file, line_num, content = line:match("^([^:]+):(%d+):%d+:(.+)$")
    if file and line_num and content then
      -- Extract require path from content
      for _, pattern_info in ipairs(REQUIRE_PATTERNS_WITH_REPLACEMENT) do
        local _, module = content:match(pattern_info.pattern)
        if module and (module == old_module_path or module:find("^" .. vim.pesc(old_module_path) .. "%.")) then
          local new_req_path = module == old_module_path
            and new_module_path
            or (new_module_path .. module:sub(#old_module_path + 1))

          changes[#changes + 1] = {
            file = path_util.normalize(path_util.join(cwd, file)),
            line = tonumber(line_num),
            old_require = module,
            new_require = new_req_path,
          }
          break
        end
      end
    end
  end

  logger.info(string.format("Ripgrep found %d require(s)", #changes))
  return changes
end

return M
