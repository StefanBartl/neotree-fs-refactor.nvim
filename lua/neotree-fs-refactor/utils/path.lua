---@module 'neotree-fs-refactor.utils.path'
---@brief Path manipulation and normalization utilities
---@description
--- Provides cross-platform path operations including normalization,
--- conversion between file paths and Lua module paths, and relative path calculations.

local M = {}

local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

--- Normalize path separators to forward slashes
---@param path string|nil Path to normalize
---@return string Normalized path
function M.normalize(path)
  if not path then return "" end
  -- Convert backslashes to forward slashes
  path = path:gsub("\\", "/")
  -- Remove duplicate slashes
  path = path:gsub("//+", "/")
  -- Remove trailing slash unless root
  if path ~= "/" then
    path = path:gsub("/$", "")
  end
  return path
end

--- Convert file path to Lua module path
--- Example: "lua/testfs/rem/da.lua" -> "testfs.rem.da"
---@param file_path string File system path
---@return string|nil Module path or nil if invalid
function M.file_to_module(file_path)
  if not file_path then return nil end

  local normalized = M.normalize(file_path)

  -- Remove .lua extension
  normalized = normalized:gsub("%.lua$", "")

  -- Find lua/ directory and take everything after it
  local lua_idx = normalized:find("/lua/")
  if lua_idx then
    normalized = normalized:sub(lua_idx + 5) -- Skip "/lua/"
  end

  -- Convert slashes to dots
  local module_path = normalized:gsub("/", ".")

  -- Remove leading/trailing dots
  module_path = module_path:gsub("^%.+", ""):gsub("%.+$", "")

  return module_path ~= "" and module_path or nil
end

--- Convert Lua module path to file path
--- Example: "testfs.rem.da" -> "lua/testfs/rem/da.lua"
---@param module_path string Module path
---@param base_path string|nil Base path (default: current working directory)
---@return string File path
function M.module_to_file(module_path, base_path)
  if not module_path then return "" end

  base_path = base_path or vim.fn.getcwd()
  local file_path = module_path:gsub("%.", "/")

  -- Check if lua/ directory exists in base_path
  local lua_dir = M.join(base_path, "lua")
  if vim.fn.isdirectory(lua_dir) == 1 then
    return M.join(lua_dir, file_path .. ".lua")
  end

  -- Fallback: assume current directory is already in lua/
  return M.join(base_path, file_path .. ".lua")
end

--- Join path components
---@param ... string Path components
---@return string Joined path
function M.join(...)
  local parts = { ... }
  local result = table.concat(parts, "/")
  return M.normalize(result)
end

--- Check if path is absolute
---@param path string Path to check
---@return boolean True if absolute
function M.is_absolute(path)
  if not path then return false end
  if is_windows then
    return path:match("^%a:") ~= nil or path:match("^\\\\") ~= nil
  else
    return path:sub(1, 1) == "/"
  end
end

--- Get relative path from base to target
---@param from string Base path
---@param to string Target path
---@return string Relative path
function M.relative(from, to)
  from = M.normalize(from)
  to = M.normalize(to)

  -- If target is inside base, return relative part
  if to:sub(1, #from) == from then
    local rel = to:sub(#from + 1)
    return (rel:gsub("^/", ""))
  end

  -- Otherwise return full target path
  return to
end

--- Check if path is inside base directory
---@param base string Base directory
---@param path string Path to check
---@return boolean True if path is inside base
function M.is_inside(base, path)
  base = M.normalize(base)
  path = M.normalize(path)
  return path:sub(1, #base) == base
end

--- Get parent directory of path
---@param path string Path
---@return string Parent directory
function M.parent(path)
  path = M.normalize(path)
  local parent = path:match("(.+)/[^/]+$")
  return parent or path
end

--- Get filename from path
---@param path string Path
---@return string Filename
function M.filename(path)
  path = M.normalize(path)
  return path:match("([^/]+)$") or path
end

--- Check if two paths are equal (case-insensitive on Windows)
---@param path1 string First path
---@param path2 string Second path
---@return boolean True if equal
function M.equals(path1, path2)
  path1 = M.normalize(path1)
  path2 = M.normalize(path2)

  if is_windows then
    return path1:lower() == path2:lower()
  else
    return path1 == path2
  end
end

return M
