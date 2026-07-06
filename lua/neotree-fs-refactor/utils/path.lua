---@module 'neotree-fs-refactor.utils.path'
---@brief Path manipulation and normalization utilities
---@description
--- Provides cross-platform path operations including normalization,
--- conversion between file paths and Lua module paths, and relative path calculations.

local M = {}

local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

--- Normalize path separators to forward slashes
---@param path string Path to normalize
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

  -- Find the *nearest* lua/ directory (rightmost match; an outer ancestor
  -- directory that happens to also be named "lua" must not be mistaken for
  -- the require-root) and take everything after it. Handles both absolute
  -- paths ("/project/lua/foo.lua") and paths rooted at "lua/" itself
  -- ("lua/foo.lua", per this function's own doc example).
  local rel = normalized:match(".*/lua/(.+)$")
  if rel then
    normalized = rel
  else
    normalized = normalized:gsub("^lua/", "")
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

--- Check if path is absolute. Recognizes both Windows-style ("C:\", "\\host\")
--- and POSIX-style ("/...") absolute paths regardless of host OS, since paths
--- can legitimately arrive from either convention (WSL mounts, Git Bash, a
--- path pasted from another OS) — not just whichever OS this is running on.
---@param path string Path to check
---@return boolean True if absolute
function M.is_absolute(path)
  if not path then return false end
  if path:match("^%a:") or path:match("^\\\\") or path:match("^//") then
    return true
  end
  return path:sub(1, 1) == "/"
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

--- Get the Neovim filetype for a path, purely from its extension (no buffer needed)
---@param file_path string
---@return string filetype Empty string if it couldn't be determined
function M.get_filetype_from_extension(file_path)
  return vim.filetype.match({ filename = file_path }) or ""
end

--- Convert a file path to a dotted Python import module name, relative to `root`
--- Example: "/proj/pkg/util/shared.py" with root "/proj" -> "pkg.util.shared"
---@param file_path string Absolute file path
---@param root? string Project root to resolve against (default: cwd)
---@return string|nil module Module path, or nil if not a .py file
function M.path_to_python_module(file_path, root)
  if not file_path or not file_path:match("%.py$") then return nil end

  root = M.normalize(root or vim.fn.getcwd())
  local rel = M.normalize(file_path)
  if rel:sub(1, #root) == root then
    rel = rel:sub(#root + 1):gsub("^/", "")
  end

  rel = rel:gsub("%.py$", ""):gsub("/__init__$", "")
  local module_path = rel:gsub("/", ".")
  return module_path ~= "" and module_path or nil
end

--- Relative path from `from_dir` to `target_path`, POSIX-style, with ".."
--- segments where needed (M.relative only handles descendants of `from_dir`).
---@param from_dir string
---@param target_path string
---@return string
local function relpath(from_dir, target_path)
  local t, f = {}, {}
  for part in M.normalize(target_path):gmatch("[^/]+") do t[#t + 1] = part end
  for part in M.normalize(from_dir):gmatch("[^/]+") do f[#f + 1] = part end

  local i = 1
  while t[i] and f[i] and t[i] == f[i] do i = i + 1 end

  local parts = {}
  for _ = i, #f do parts[#parts + 1] = ".." end
  for j = i, #t do parts[#parts + 1] = t[j] end

  return #parts > 0 and table.concat(parts, "/") or "."
end

--- Compute the relative import specifier a file in `ref_dir` would use to
--- import `target_path` (extensionless, "/index" collapsed, "./"-prefixed
--- unless it already climbs up with "..").
---@param target_path string Absolute path of the module being imported
---@param ref_dir string Absolute directory of the file doing the importing
---@return string
function M.to_relative_import(target_path, ref_dir)
  local rel = relpath(ref_dir, target_path)
    :gsub("%.tsx?$", ""):gsub("%.jsx?$", ""):gsub("/index$", "")
  if rel:sub(1, 2) ~= ".." then rel = "./" .. rel end
  return rel
end

return M
