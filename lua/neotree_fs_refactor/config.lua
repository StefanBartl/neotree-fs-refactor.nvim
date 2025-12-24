---@module 'neotree_fs_refactor.config'
---@brief Configuration management for neotree-fs-refactor
---@description
--- Manages plugin configuration with lazy initialization and fallback defaults.
--- Uses metatable-based on-demand resolution to avoid unnecessary deep copies.

local notify = require("neotree_fs_refactor.utils.notify")

local M = {}

---@type Neotree.FSRefactor.Config|nil
local user_config = nil

---Default configuration values
---@type Neotree.FSRefactor.Config
local defaults = {
  enable_lsp = true,
  enable_fallback = true,
  auto_apply = false,
  preview_changes = true,
  notify_level = "info",
  ignore_patterns = { ".git", "node_modules", ".venv", "__pycache__", "target" },
  file_type_filters = nil, -- nil = all filetypes
  max_file_size_kb = 1024, -- 1MB
  timeout_ms = 5000,
  fallback = {
    enabled = true,
    tool = "ripgrep",
    case_sensitive = true,
    whole_word = true,
    confidence_threshold = "medium",
  },
}

---Metatable for lazy initialization of config fields
---@type table
local config_mt
config_mt = {
  __index = function(tbl, key)
    local default_val = defaults[key]

    -- For nested tables, create a new table with the same metatable recursion
    if type(default_val) == "table" then
      local nested = setmetatable({}, config_mt)
      rawset(tbl, key, nested)
      return nested
    end

    return default_val
  end,
}

---Initialize plugin configuration
---@param opts Neotree.FSRefactor.Config|nil User-provided configuration
---@return nil
function M.setup(opts)
  opts = opts or {}

  -- Type validation for critical fields
  if opts.enable_lsp ~= nil and type(opts.enable_lsp) ~= "boolean" then
    notify.error("config.enable_lsp must be boolean, got " .. type(opts.enable_lsp))
    opts.enable_lsp = nil
  end

  if opts.timeout_ms ~= nil and type(opts.timeout_ms) ~= "number" then
    notify.error("config.timeout_ms must be number, got " .. type(opts.timeout_ms))
    opts.timeout_ms = nil
  end

  -- Apply metatable for lazy field resolution
  user_config = setmetatable(opts, config_mt)
end

---Get configuration value by key
---@param key string Configuration key
---@return any # Configuration value
function M.get(key)
  if not user_config then
    notify.warn("neotree-fs-refactor not configured, using defaults")
    M.setup({})
  end

  if not user_config then
    notify.error("[neotree-fs-refactor] config is nil")
    return nil
  end

  if not user_config[key] then
    notify.warn("configuration key is nil")
  end

  return user_config[key]
end

---Get entire configuration object
---@return Neotree.FSRefactor.Config|nil
function M.get_all()
  if not user_config then
    M.setup({})
  end
  return user_config
end

---Validate current configuration
---@return boolean success
---@return string|nil error_message
function M.validate()
  local cfg = M.get_all()

  if not cfg then
    notify.error("config is nil")
    return false, nil
  end

  -- Check timeout is reasonable
  if cfg.timeout_ms < 100 or cfg.timeout_ms > 60000 then
    return false, "timeout_ms must be between 100 and 60000"
  end

  -- Check max file size is reasonable
  if cfg.max_file_size_kb < 1 or cfg.max_file_size_kb > 102400 then
    return false, "max_file_size_kb must be between 1 and 102400 (100MB)"
  end

  -- Validate notify level
  local valid_levels = { error = true, warn = true, info = true, debug = true }
  if not valid_levels[cfg.notify_level] then
    return false, "notify_level must be one of: error, warn, info, debug"
  end

  -- Validate fallback tool
  if cfg.fallback.enabled then
    local valid_tools = { ripgrep = true, native = true }
    if not valid_tools[cfg.fallback.tool] then
      return false, "fallback.tool must be 'ripgrep' or 'native'"
    end

    -- Check if ripgrep is available
    if cfg.fallback.tool == "ripgrep" then
      if vim.fn.executable("rg") ~= 1 then
        return false, "ripgrep (rg) not found in PATH but fallback.tool is set to 'ripgrep'"
      end
    end
  end

  return true, nil
end

---Check if LSP refactoring is enabled
---@return boolean
function M.is_lsp_enabled()
  return M.get("enable_lsp") == true
end

---Check if fallback search is enabled
---@return boolean
function M.is_fallback_enabled()
  return M.get("enable_fallback") == true
end

---Check if changes should be auto-applied
---@return boolean
function M.should_auto_apply()
  return M.get("auto_apply") == true
end

---Check if preview should be shown
---@return boolean
function M.should_show_preview()
  return M.get("preview_changes") == true
end

---Get notification level as vim.log.levels value
---@return integer
function M.get_notify_level()
  local level_map = {
    error = vim.log.levels.ERROR,
    warn = vim.log.levels.WARN,
    info = vim.log.levels.INFO,
    debug = vim.log.levels.DEBUG,
  }
  return level_map[M.get("notify_level")] or vim.log.levels.INFO
end

---Reset configuration to defaults (useful for testing)
---@return nil
function M.reset()
  user_config = nil
end

return M
