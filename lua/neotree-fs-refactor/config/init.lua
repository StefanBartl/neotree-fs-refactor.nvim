---@module 'neotree-fs-refactor.config'
---@brief Configuration management — defaults, merging, validation.
---@description
--- Plugin-side defaults live in `neotree-fs-refactor.config.DEFAULTS`; this
--- module deep-merges the user's `setup({})` config on top and exposes the
--- active config.

local M = {}

---@type Neotree.FSRefactor.Config
local _defaults = require("neotree-fs-refactor.config.DEFAULTS")

---@type Neotree.FSRefactor.Config
local _active = vim.deepcopy(_defaults)

---Apply user config on top of defaults.
---@param user Neotree.FSRefactor.Config?
---@return Neotree.FSRefactor.Config
function M.setup(user)
  _active = vim.tbl_deep_extend("force", vim.deepcopy(_defaults), user or {})
  return _active
end

---Return the active configuration.
---@return Neotree.FSRefactor.Config
function M.get()
  return _active
end

---Validate the active config and return an error message when invalid.
---@return boolean ok
---@return string? err
function M.validate()
  local cfg = _active
  if type(cfg.file_types) ~= "table" then
    return false, "config.file_types must be a table"
  end
  if type(cfg.max_file_size) ~= "number" or cfg.max_file_size <= 0 then
    return false, "config.max_file_size must be a positive number"
  end
  if type(cfg.debounce_ms) ~= "number" or cfg.debounce_ms < 0 then
    return false, "config.debounce_ms must be >= 0"
  end
  return true, nil
end

return M
