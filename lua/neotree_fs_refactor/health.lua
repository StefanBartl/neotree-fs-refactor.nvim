---@module 'neotree_fs_refactor.health'
---@brief Health check for neotree-fs-refactor plugin
---@description
--- Implements :checkhealth neotree-fs-refactor functionality
--- to verify plugin dependencies and configuration.

local health = vim.health or require("health")

local M = {}

local str_format = string.format

---Check if a module can be loaded
---@param module_name string Module name
---@return boolean success
---@return any module_or_error
local function check_module(module_name)
  local ok, result = pcall(require, module_name)
  return ok, result
end

---Check if an executable is available
---@param exe string Executable name
---@return boolean
local function check_executable(exe)
  return vim.fn.executable(exe) == 1
end

---Main health check function
---@return nil
function M.check()
  health.start("neotree-fs-refactor")

  -- Check Neovim version
  local nvim_version = vim.version()
  if nvim_version.major == 0 and nvim_version.minor < 9 then
    health.error(
      "Neovim >= 0.9.0 required",
      str_format("Current version: %d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch)
    )
  else
    health.ok(str_format("Neovim version: %d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch))
  end

  -- Check Neo-tree
  local neotree_ok, _ = check_module("neo-tree")
  if neotree_ok then
    health.ok("Neo-tree is installed")

    -- Check Neo-tree events
    local events_ok = check_module("neo-tree.events")
    if events_ok then
      health.ok("Neo-tree events module available")
    else
      health.error("Neo-tree events module not found")
    end
  else
    health.error(
      "Neo-tree is not installed",
      "Install neo-tree.nvim: https://github.com/nvim-neo-tree/neo-tree.nvim"
    )
  end

  -- Check plugin modules
  local modules = {
    "neotree_fs_refactor.config",
    "neotree_fs_refactor.utils",
    "neotree_fs_refactor.lsp",
    "neotree_fs_refactor.fallback",
    "neotree_fs_refactor.orchestrator",
    "neotree_fs_refactor.ui.preview",
    "neotree_fs_refactor.neotree",
  }

  local all_modules_ok = true
  for i = 1, #modules do
    local ok, err = check_module(modules[i])
    if not ok then
      health.error(str_format("Failed to load %s: %s", modules[i], tostring(err)))
      all_modules_ok = false
    end
  end

  if all_modules_ok then
    health.ok("All plugin modules loaded successfully")
  end

  -- Check LSP
  health.start("LSP Integration")

  local lsp_clients = vim.lsp.get_clients()
  if #lsp_clients > 0 then
    health.ok(str_format("%d LSP client(s) active", #lsp_clients))

    for i = 1, #lsp_clients do
      local client = lsp_clients[i]
      local caps = client.server_capabilities

      if caps and caps.workspace and caps.workspace.fileOperations then
        if caps.workspace.fileOperations.willRename then
          health.ok(str_format("  %s: supports willRename", client.name))
        else
          health.warn(str_format("  %s: does not support willRename", client.name))
        end
      else
        health.warn(str_format("  %s: no fileOperations support", client.name))
      end
    end
  else
    health.warn("No LSP clients currently active")
  end

  -- Check fallback tools
  health.start("Fallback Search Tools")

  if check_executable("rg") then
    health.ok("ripgrep (rg) is available")

    -- Check ripgrep version
    local rg_version = vim.fn.system("rg --version")
    if rg_version then
      local version_line = vim.split(rg_version, "\n")[1]
      if version_line then
        health.info("  " .. version_line)
      end
    end
  else
    health.warn(
      "ripgrep (rg) not found",
      "Install ripgrep for faster fallback search: https://github.com/BurntSushi/ripgrep"
    )
  end

  -- Check configuration
  health.start("Configuration")

  local config_ok, config = check_module("neotree_fs_refactor.config")
  if config_ok then
    -- Try to validate config
    local valid, err = pcall(function()
      return config.validate()
    end)

    if valid then
      health.ok("Configuration is valid")

      -- Show key settings
      local cfg = config.get_all()
      health.info(str_format("  LSP enabled: %s", tostring(cfg.enable_lsp)))
      health.info(str_format("  Fallback enabled: %s", tostring(cfg.enable_fallback)))
      health.info(str_format("  Auto-apply: %s", tostring(cfg.auto_apply)))
      health.info(str_format("  Preview: %s", tostring(cfg.preview_changes)))
      health.info(str_format("  Timeout: %dms", cfg.timeout_ms))
      health.info(str_format("  Fallback tool: %s", cfg.fallback.tool))
    else
      health.error("Configuration validation failed", tostring(err))
    end
  end

  -- Check initialization
  health.start("Plugin Status")

  local plugin_ok, plugin = check_module("neotree_fs_refactor")
  if plugin_ok and plugin.is_initialized() then
    health.ok("Plugin is initialized")
  else
    health.warn(
      "Plugin not initialized",
      "Call require('neotree_fs_refactor').setup() in your config"
    )
  end
end

return M
