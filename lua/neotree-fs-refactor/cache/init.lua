---@module 'neotree-fs-refactor.cache'
---@brief Cache management system for require() statements
---@description
--- Manages persistent cache of require() statements found in Lua files.
--- Supports hierarchical cache management, incremental updates, and automatic cleanup.

local logger = require("neotree-fs-refactor.utils.logger")
local path_util = require("neotree-fs-refactor.utils.path")

local M = {}


---@type Neotree.FSRefactor.CacheConfig|nil
M.config = nil

---@type Neotree.FSRefactor.CacheData|nil
M._current_cache = nil

---@type string|nil
M._current_cache_file = nil

--- Initialize cache system
---@param config Neotree.FSRefactor.CacheConfig Cache configuration
---@return nil
function M.init(config)
  M.config = config
  logger.debug("Cache system initialized")
end

--- Get cache file path for a given CWD
---@param cwd string Current working directory
---@return string Cache file path
local function get_cache_file_path(cwd)
  cwd = path_util.normalize(cwd)
  -- Create a safe filename from CWD
  local safe_name = cwd:gsub("[^%w]", "_")
  return path_util.join(M.config.path, safe_name .. ".json")
end

--- Load cache from disk
---@param cache_file string Path to cache file
---@return Neotree.FSRefactor.CacheData|nil Cache data or nil if not found/invalid
local function load_cache(cache_file)
  if vim.fn.filereadable(cache_file) == 0 then
    logger.debug("Cache file not found: " .. cache_file)
    return nil
  end

  local ok, content = pcall(function()
    local lines = vim.fn.readfile(cache_file)
    return table.concat(lines, "\n")
  end)

  if not ok then
    logger.warn("Failed to read cache file: " .. cache_file)
    return nil
  end

  local decode_ok, data = pcall(vim.fn.json_decode, content)
  if not decode_ok or type(data) ~= "table" then
    logger.warn("Invalid cache file format: " .. cache_file)
    return nil
  end

  -- Update last_accessed timestamp
  data.last_accessed = os.time()

  logger.debug(string.format("Loaded cache from %s (%d entries)", cache_file, vim.tbl_count(data.entries or {})))
  return data
end

--- Save cache to disk
---@param cache_file string Path to cache file
---@param data Neotree.FSRefactor.CacheData Cache data to save
---@return boolean Success
local function save_cache(cache_file, data)
  data.last_updated = os.time()
  data.last_accessed = os.time()

  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    logger.error("Failed to encode cache data")
    return false
  end

  local write_ok, err = pcall(vim.fn.writefile, { json }, cache_file)
  if not write_ok then
    logger.error("Failed to write cache file: " .. tostring(err))
    return false
  end

  logger.debug("Saved cache to " .. cache_file)
  return true
end

--- Get or load cache for current CWD
---@param cwd string|nil Current working directory (default: getcwd())
---@return Neotree.FSRefactor.CacheData|nil Cache data
function M.get_cache(cwd)
  cwd = cwd or vim.fn.getcwd()
  cwd = path_util.normalize(cwd)

  -- Check if we already have this cache loaded
  if M._current_cache and M._current_cache.cwd == cwd then
    M._current_cache.last_accessed = os.time()
    return M._current_cache
  end

  -- Try to load from disk
  local cache_file = get_cache_file_path(cwd)
  local cache = load_cache(cache_file)

  if cache then
    M._current_cache = cache
    M._current_cache_file = cache_file
    return cache
  end

  -- Check for parent directory cache
  local parent = path_util.parent(cwd)
  if parent ~= cwd and path_util.is_absolute(parent) then
    local parent_cache_file = get_cache_file_path(parent)
    local parent_cache = load_cache(parent_cache_file)

    if parent_cache then
      logger.debug(string.format("Using parent cache from %s for %s", parent, cwd))
      -- Filter entries relevant to current CWD
      local filtered_entries = {}
      for file, entries in pairs(parent_cache.entries or {}) do
        if path_util.is_inside(cwd, file) then
          filtered_entries[file] = entries
        end
      end

      -- Create new cache with filtered entries
      local new_cache = {
        version = "1.0.0",
        cwd = cwd,
        last_updated = os.time(),
        last_accessed = os.time(),
        entries = filtered_entries,
      }

      M._current_cache = new_cache
      M._current_cache_file = cache_file
      return new_cache
    end
  end

  logger.debug("No cache found for " .. cwd)
  return nil
end

--- Create new cache for CWD
---@param cwd string|nil Current working directory
---@return Neotree.FSRefactor.CacheData New cache data
function M.create_cache(cwd)
  cwd = cwd or vim.fn.getcwd()
  cwd = path_util.normalize(cwd)

  local cache = {
    version = "1.0.0",
    cwd = cwd,
    last_updated = os.time(),
    last_accessed = os.time(),
    entries = {},
  }

  M._current_cache = cache
  M._current_cache_file = get_cache_file_path(cwd)

  logger.debug("Created new cache for " .. cwd)
  return cache
end

--- Save current cache to disk
---@return boolean Success
function M.save_current_cache()
  if not M._current_cache or not M._current_cache_file then
    logger.warn("No cache to save")
    return false
  end

  return save_cache(M._current_cache_file, M._current_cache)
end

--- Clean up old cache files
---@return nil
function M.cleanup_old_caches()
  if not M.config then return end

  local cache_dir = M.config.path
  local max_age_days = M.config.cleanup_after_days
  local max_age_seconds = max_age_days * 24 * 60 * 60
  local current_time = os.time()

  local ok, files = pcall(vim.fn.glob, path_util.join(cache_dir, "*.json"), false, true)
  if not ok or not files then
    logger.debug("No cache files to clean up")
    return
  end

  local cleaned = 0
  for _, file in ipairs(files) do
    local cache = load_cache(file)
    if cache and cache.last_accessed then
      local age = current_time - cache.last_accessed
      if age > max_age_seconds then
        vim.fn.delete(file)
        cleaned = cleaned + 1
        logger.debug(string.format("Deleted old cache: %s (age: %d days)", file, math.floor(age / 86400)))
      end
    end
  end

  if cleaned > 0 then
    logger.info(string.format("Cleaned up %d old cache file(s)", cleaned))
  end
end

--- Update cache for CWD change
---@param new_cwd string New working directory
---@return nil
function M.update_for_cwd(new_cwd)
  logger.debug("CWD changed to: " .. new_cwd)

  -- Load or create cache for new CWD
  local cache = M.get_cache(new_cwd)
  if not cache then
    cache = M.create_cache(new_cwd)
    -- Trigger async scan
    local scanner = require("neotree-fs-refactor.cache.scanner_async")
    scanner.scan_directory(new_cwd, cache)
  end
end

--- Update single file in cache
---@param file_path string Absolute file path
---@return nil
function M.update_single_file(file_path)
  if not M._current_cache then
    logger.debug("No cache loaded, skipping incremental update")
    return
  end

  file_path = path_util.normalize(file_path)

  local scanner = require("neotree-fs-refactor.cache.scanner_async")
  scanner.scan_single_file(file_path, M._current_cache)

  -- Save cache after update
  vim.schedule(function()
    M.save_current_cache()
  end)
end

--- Get require entries for a specific module path
---@param module_path string Lua module path (e.g., "testfs.rem.da")
---@return table<string, Neotree.FSRefactor.CacheEntry[]> Map of files that require this module
function M.find_requires(module_path)
  local cache = M.get_cache()
  if not cache then
    return {}
  end

  local results = {}
  for file, entries in pairs(cache.entries or {}) do
    for _, entry in ipairs(entries) do
      if entry.require_path == module_path or entry.require_path:find("^" .. vim.pesc(module_path) .. "%.") then
        results[file] = results[file] or {}
        table.insert(results[file], entry)
      end
    end
  end

  return results
end

return M
