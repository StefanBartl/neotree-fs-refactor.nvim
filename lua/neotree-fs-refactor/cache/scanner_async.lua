---@module 'neotree-fs-refactor.cache.scanner_async'
---@brief Asynchronous directory scanner for require() statements
---@description
--- Scans Lua files in a directory tree to find require() statements.
--- Uses vim.loop (libuv) for async file operations to avoid blocking the UI.

local logger = require("neotree-fs-refactor.utils.logger")
local path_util = require("neotree-fs-refactor.utils.path")

local M = {}

local uv = vim.loop

--- Require patterns to match (in order of priority)
---@type string[]
local REQUIRE_PATTERNS = {
  'require%s*%(%s*["\']([^"\']+)["\']%s*%)', -- require("module")
  'require%s*["\']([^"\']+)["\']', -- require "module"
  "require%s*%(%s*'([^']+)'%s*%)", -- require('module')
  "require%s*'([^']+)'", -- require 'module'
}

--- Parse a single line for require statements
---@param line string Line content
---@param line_num integer Line number
---@return Neotree.FSRefactor.CacheEntry|nil Entry if require found
local function parse_line_for_require(line, line_num)
  for _, pattern in ipairs(REQUIRE_PATTERNS) do
    local module_path = line:match(pattern)
    if module_path then
      return {
        line = line_num,
        require_path = module_path,
      }
    end
  end
  return nil
end

--- Parse file content for require statements
---@param content string File content
---@return Neotree.FSRefactor.CacheEntry[] List of require entries
local function parse_file_content(content)
  local entries = {}
  local line_num = 0

  for line in content:gmatch("[^\r\n]+") do
    line_num = line_num + 1
    local entry = parse_line_for_require(line, line_num)
    if entry then
      entries[#entries + 1] = entry
    end
  end

  return entries
end

--- Read file asynchronously
---@param file_path string Absolute file path
---@param callback fun(err: string|nil, content: string|nil)
local function read_file_async(file_path, callback)
  uv.fs_open(file_path, "r", 438, function(err_open, fd)
    if err_open or not fd then
      callback(err_open or "Failed to open file", nil)
      return
    end

    uv.fs_fstat(fd, function(err_stat, stat)
      if err_stat or not stat then
        uv.fs_close(fd, function() end)
        callback(err_stat or "Failed to stat file", nil)
        return
      end

      uv.fs_read(fd, stat.size, 0, function(err_read, data)
        uv.fs_close(fd, function() end)

        if err_read then
          callback(err_read, nil)
          return
        end

        callback(nil, data)
      end)
    end)
  end)
end

--- Scan single file and update cache
---@param file_path string Absolute file path
---@param cache Neotree.FSRefactor.CacheData Cache to update
---@return nil
function M.scan_single_file(file_path, cache)
  if not file_path:match("%.lua$") then
    return
  end

  file_path = path_util.normalize(file_path)

  read_file_async(file_path, function(err, content)
    if err then
      logger.debug(string.format("Failed to read %s: %s", file_path, err))
      return
    end

    if not content then
      logger.warn("no content to read file")
      return
    end

    vim.schedule(function()
      local entries = parse_file_content(content)

      if #entries > 0 then
        cache.entries[file_path] = entries
        logger.debug(string.format("Found %d require(s) in %s", #entries, file_path))
      else
        -- Remove from cache if no requires found
        cache.entries[file_path] = nil
      end
    end)
  end)
end

--- Scan directory recursively
---@param dir_path string Directory to scan
---@param cache Neotree.FSRefactor.CacheData Cache to populate
---@param on_complete fun()|nil Callback when scan completes
---@return nil
function M.scan_directory(dir_path, cache, on_complete)
  dir_path = path_util.normalize(dir_path)

  local files_found = 0
  local files_processed = 0
  local start_time = os.clock()

  logger.info(string.format("Starting directory scan: %s", dir_path))

  --- Recursive scan function
  ---@param path string Current path
  local function scan_recursive(path)
    uv.fs_scandir(path, function(err, handle)
      if err or not handle then
        logger.debug(string.format("Failed to scan %s: %s", path, err or "unknown"))
        return
      end

      while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then break end

        local full_path = path_util.join(path, name)

        if type == "directory" then
          -- Skip hidden directories and common ignore patterns
          if not name:match("^%.") and name ~= "node_modules" and name ~= ".git" then
            scan_recursive(full_path)
          end
        elseif type == "file" and name:match("%.lua$") then
          files_found = files_found + 1

          read_file_async(full_path, function(read_err, content)
            if not read_err and content then
              vim.schedule(function()
                local entries = parse_file_content(content)
                if #entries > 0 then
                  cache.entries[full_path] = entries
                end

                files_processed = files_processed + 1

                -- Check if scan complete
                if files_processed == files_found then
                  local elapsed = os.clock() - start_time
                  logger.info(string.format(
                    "Scan complete: %d files, %d with requires, %.2fs",
                    files_found,
                    vim.tbl_count(cache.entries),
                    elapsed
                  ))

                  -- Save cache
                  local cache_manager = require("neotree-fs-refactor.cache")
                  cache_manager.save_current_cache()

                  if on_complete then
                    on_complete()
                  end
                end
              end)
            else
              files_processed = files_processed + 1
            end
          end)
        end
      end
    end)
  end

  -- Start scanning
  scan_recursive(dir_path)
end

return M
