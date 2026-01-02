---@module 'neotree-fs-refactor.utils.scanner'
---@brief Bridge module for backwards compatibility
---@description
--- This module provides backwards compatibility by bridging to the new
--- cache-based architecture. Use the new cache system directly for better performance.

local M = {}

local logger = require("neotree-fs-refactor.utils.logger")
local path_util = require("neotree-fs-refactor.utils.path")

--- Find files with references to a given path (legacy API)
---@param cwd string Current working directory
---@param target_path string Path to search for
---@param config table Configuration
---@return string[] List of files containing references
---@diagnostic disable-next-line: unused-local
function M.find_files_with_references(cwd, target_path, config)
  logger.warn("Using legacy scanner.find_files_with_references - consider using cache system")

  -- Convert path to module
  local target_module = path_util.file_to_module(target_path)

  if not target_module then
    logger.warn("Could not convert path to module: " .. target_path)
    return {}
  end

  -- Use cache system to find references
  local cache = require("neotree-fs-refactor.cache")
  local current_cache = cache.get_cache(cwd)

  if not current_cache then
    -- No cache available, trigger scan
    logger.info("No cache found, scanning directory...")
    current_cache = cache.create_cache(cwd)

    -- Use optimized scanner
    local scanner = require("neotree-fs-refactor.cache.scanner_optimized")
    scanner.scan_directory_optimized(cwd, current_cache, function()
      logger.debug("Background scan complete")
    end)

    -- Return empty for now (async scan in progress)
    return {}
  end

  -- Find files that reference this module
  local results = cache.find_requires(target_module)

  -- Convert to simple file list
  local files = {}
  for file, _ in pairs(results) do
    files[#files + 1] = file
  end

  logger.debug(string.format("Found %d file(s) referencing %s", #files, target_module))

  return files
end

--- Build search patterns (legacy API)
---@param target_path string Target path
---@return table[] Search patterns
function M.build_search_patterns(target_path)
  local path_util_compat = require("neotree-fs-refactor.utils.path")

  local normalized = path_util_compat.normalize(target_path)
  local relative = path_util_compat.to_relative_import(normalized)
  local module = path_util_compat.file_to_module(normalized)

  local patterns = {}

  -- Lua require patterns
  if module then
    patterns[#patterns + 1] = {
      pattern = string.format('require[%s(]*["\']%s["\']', "%s", vim.pesc(module)),
      type = "lua_require",
    }
  end

  -- Relative path patterns
  if relative then
    patterns[#patterns + 1] = {
      pattern = vim.pesc(relative),
      type = "relative_path",
    }
  end

  return patterns
end

--- Deprecated: Use cache system directly
---@deprecated
function M.scan_directory()
  error("scanner.scan_directory is deprecated. Use cache.scanner_optimized.scan_directory_optimized instead")
end

return M
