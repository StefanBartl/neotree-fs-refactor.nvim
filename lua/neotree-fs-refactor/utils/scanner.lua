---@module 'neotree-fs-refactor.utils.scanner'
---@brief Synchronous project scan for files referencing a renamed path
---@description
--- Finds files that plausibly reference a given path, restricted to the
--- renamed file's own language family (lua ← lua, .py ← .py, ts/js ← any of
--- ts/tsx/js/jsx). Uses ripgrep when available; falls back to a pure-Lua
--- recursive directory walk otherwise, so the plugin has no hard external
--- dependency.

local M = {}

local logger = require("neotree-fs-refactor.utils.logger")
local path_util = require("neotree-fs-refactor.utils.path")

--- Default directory names to always skip during a scan
---@type table<string, boolean>
local SKIP_DIRS = {
  [".git"] = true,
  node_modules = true,
  dist = true,
  build = true,
}

--- Pick the search needle + extension whitelist for a rename, based on the
--- renamed file's own filetype.
---@param target_path string
---@return string? needle, string[]? extensions
local function scan_spec(target_path)
  local ft = path_util.get_filetype_from_extension(target_path)

  if ft == "lua" then
    local m = path_util.file_to_module(target_path)
    return m, m and { "lua" } or nil
  elseif ft == "python" then
    local m = path_util.path_to_python_module(target_path)
    return m, m and { "py" } or nil
  elseif ft:match("^typescript") or ft:match("^javascript") then
    local base = path_util.filename(target_path):gsub("%.[tj]sx?$", "")
    return base, { "ts", "tsx", "js", "jsx" }
  elseif ft == "" then
    -- Likely a directory rename (no extension to detect a language from) —
    -- by the time this runs, target_path itself has usually already been
    -- moved away on disk, so its existence can't be checked here.
    -- file_to_module() dot-joins the *entire* path as a last resort when it
    -- finds no "lua/" marker, so it would misfire as a bogus "match" for any
    -- directory (e.g. a renamed Python package) if called unconditionally —
    -- only treat this as Lua when the path is actually under a lua/ tree.
    local unix = target_path:gsub("\\", "/")
    if unix:match("/lua/") or unix:match("^lua/") then
      local m = path_util.file_to_module(target_path)
      return m, m and { "lua" } or nil
    end
  end

  return nil, nil
end

--- Scan via ripgrep (fixed-string, extension-filtered)
---@param root string
---@param needle string
---@param exts string[]
---@return string[]
local function scan_with_rg(root, needle, exts)
  local cmd = { "rg", "--files-with-matches", "--fixed-strings", "--color=never" }
  for _, ext in ipairs(exts) do
    cmd[#cmd + 1] = "-g"
    cmd[#cmd + 1] = "*." .. ext
  end
  for dir in pairs(SKIP_DIRS) do
    cmd[#cmd + 1] = "-g"
    cmd[#cmd + 1] = "!" .. dir .. "/*"
  end
  cmd[#cmd + 1] = "--"
  cmd[#cmd + 1] = needle
  cmd[#cmd + 1] = root

  -- Argv form (no shell in between): nothing to quote/escape, and no
  -- dependency on &shell being cmd.exe-compatible.
  local result = vim.system(cmd, { text = true }):wait()
  if result.code > 1 then -- rg: 0 = matches, 1 = no matches, >1 = error
    logger.warn("ripgrep exited with code " .. tostring(result.code))
    return {}
  end

  local files = {}
  for line in (result.stdout or ""):gmatch("[^\r\n]+") do
    files[#files + 1] = path_util.normalize(line)
  end
  return files
end

--- Cross-platform fallback with no external dependency: walk the tree and
--- grep each candidate-extension file for the needle as a plain substring.
---@param root string
---@param needle string
---@param exts string[]
---@param max_file_size number
---@return string[]
local function scan_with_lua_walk(root, needle, exts, max_file_size)
  local ext_set = {}
  for _, e in ipairs(exts) do ext_set[e] = true end

  local files = {}

  local function has_match(file_path)
    local f = io.open(file_path, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    return content ~= nil and content:find(needle, 1, true) ~= nil
  end

  local function walk(dir)
    local ok, entries = pcall(vim.fn.readdir, dir)
    if not ok or not entries then return end

    for _, name in ipairs(entries) do
      local full = path_util.join(dir, name)
      if vim.fn.isdirectory(full) == 1 then
        if not SKIP_DIRS[name] and not name:match("^%.") then
          walk(full)
        end
      else
        local ext = name:match("%.([%w]+)$")
        if ext and ext_set[ext] then
          local stat = vim.uv.fs_stat(full)
          if stat and stat.size <= max_file_size and has_match(full) then
            files[#files + 1] = full
          end
        end
      end
    end
  end

  walk(root)
  return files
end

--- Find files that plausibly reference `target_path`, scoped to its own
--- language family and to `cwd`.
---@param cwd string Directory to scan
---@param target_path string Path being renamed/moved
---@param config Neotree.FSRefactor.Config Plugin configuration
---@return string[] List of candidate file paths
function M.find_files_with_references(cwd, target_path, config)
  local needle, exts = scan_spec(target_path)
  if not needle or needle == "" or not exts then
    logger.debug("No search pattern for " .. tostring(target_path) .. ", skipping scan")
    return {}
  end

  if vim.fn.executable("rg") == 1 then
    return scan_with_rg(cwd, needle, exts)
  end

  logger.debug("ripgrep not found, using pure-Lua directory walk")
  return scan_with_lua_walk(cwd, needle, exts, config and config.max_file_size or (1024 * 1024))
end

return M
