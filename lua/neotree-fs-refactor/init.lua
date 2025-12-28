---@module 'neotree-fs-refactor'
---@brief Entry point for neotree-fs-refactor.nvim plugin
---@description
--- This plugin automatically refactors file/folder references in your codebase
--- when files are renamed, moved, or deleted in neo-tree.
---
--- Key features:
--- - Listens to neo-tree file operations (rename, move, delete)
--- - Scans all buffers and project files for references
--- - Updates import paths, require statements, and file references
--- - Supports Lua, TypeScript, JavaScript, Python, and more
--- - Respects git-ignored files (configurable)
--- - Provides undo functionality via native Neovim undo


local logger = require("neotree-fs-refactor.utils.logger")
local path_util = require("neotree-fs-refactor.utils.path")
local require_finder = require("neotree-fs-refactor.refactor.require_finder")
local file_updater = require("neotree-fs-refactor.refactor.file_updater")
local notify = require("neotree-fs-refactor.utils.notify")

local M = {}

local str_fmt = string.format

---@type Neotree.FSRefactor.Config
local default_config = {
  enabled = true,
  auto_save = false,
  notify_on_refactor = true,
  ignore_patterns = {
    "node_modules/**",
    ".git/**",
    "dist/**",
    "build/**",
    "*.min.js",
  },
  file_types = {
    lua = true,
    typescript = true,
    javascript = true,
    typescriptreact = true,
    javascriptreact = true,
    python = true,
    go = true,
    rust = true,
    cpp = true,
    c = true,
  },
  max_file_size = 1024 * 1024, -- 1MB
  debounce_ms = 100,
}

---@type Neotree.FSRefactor.Config
M.config = vim.deepcopy(default_config)

---Setup function for the plugin
---@param opts Neotree.FSRefactor.Config|nil User configuration
---@return nil
function M.setup(opts)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})

  if not M.config.enabled then
    return
  end

  -- Verify neo-tree is installed
  local neo_tree_ok = pcall(require, "neo-tree")
  if not neo_tree_ok then
    notify.error("[neotree-fs-refactor] neo-tree.nvim is required but not installed")
    return
  end

  -- Load core modules
  local ok, err = pcall(function()
    require("neotree-fs-refactor.core.event_handlers").setup(M.config)
  end)

  if not ok then
    notify.error(str_fmt("[neotree-fs-refactor] Setup failed: %s", err))
    return
  end

  notify.info("[neotree-fs-refactor] Plugin loaded successfully")
end

---Check plugin health
---@return nil
function M.check()
  local health = vim.health or require("health")

  health.start("neotree-fs-refactor")

  -- Check neo-tree
  local neo_tree_ok = pcall(require, "neo-tree")
  if neo_tree_ok then
    health.ok("neo-tree.nvim is installed")
  else
    health.error("neo-tree.nvim is not installed")
  end

  -- Check plenary (used by neo-tree)
  local plenary_ok = pcall(require, "plenary")
  if plenary_ok then
    health.ok("plenary.nvim is installed")
  else
    health.warn("plenary.nvim is not installed (recommended)")
  end

  -- Check configuration
  if M.config.enabled then
    health.ok("Plugin is enabled")
  else
    health.warn("Plugin is disabled in configuration")
  end

  health.info(str_fmt("Auto-save: %s", M.config.auto_save))
  health.info(str_fmt("Max file size: %d bytes", M.config.max_file_size))
end

--- Handle file or directory rename/move
---@param old_path string Old file/directory path (absolute)
---@param new_path string New file/directory path (absolute)
---@return nil
function M.handle_rename(old_path, new_path)
  old_path = path_util.normalize(old_path)
  new_path = path_util.normalize(new_path)

  logger.info(string.format("Refactoring:\n  File: %s → %s", old_path, new_path))

  -- Convert paths to module paths
  local old_module = path_util.file_to_module(old_path)
  local new_module = path_util.file_to_module(new_path)

  if not old_module or not new_module then
    logger.warn("Could not determine module paths, skipping refactor")
    logger.debug(string.format("old_module: %s, new_module: %s", tostring(old_module), tostring(new_module)))
    return
  end

  logger.info(string.format("  Module: %s → %s", old_module, new_module))

  -- Find all requires that need updating
  local changes = require_finder.find_require_changes(old_module, new_module)

  if #changes == 0 then
    logger.info("No references found")
    return
  end

  -- Verify each change (find actual line numbers)
  local verified_changes = {}
  for _, change in ipairs(changes) do
    if require_finder.verify_and_update_change(change) then
      verified_changes[#verified_changes + 1] = change
    end
  end

  if #verified_changes == 0 then
    logger.warn("No changes could be verified")
    return
  end

  logger.info(string.format("Verified %d/%d change(s)", #verified_changes, #changes))

  -- Get config
  local main = require("neotree-fs-refactor")
  local config = main.get_config()

  if not config then
    logger.error("Plugin not initialized")
    return
  end

  -- Show picker if enabled
  if config.refactor.show_picker then
    local picker = require("neotree-fs-refactor.ui.picker")
    picker.show(verified_changes, function(selected_changes)
      M._apply_changes(selected_changes, config.refactor.dry_run, config)
    end)
  else
    -- Apply directly
    M._apply_changes(verified_changes, config.refactor.dry_run, config)
  end
end

--- Apply changes (internal)
---@param changes Neotree.FSRefactor.RequireChange[] Changes to apply
---@param dry_run boolean Whether to run in dry-run mode
---@param config Neotree.FSRefactor.Config Configuration
---@return nil
function M._apply_changes(changes, dry_run, config)
  if #changes == 0 then
    logger.info("No changes selected")
    return
  end

  -- Apply changes
  local results = file_updater.apply_changes(changes, dry_run)

  -- Update cache for modified files
  if not dry_run then
    local cache = require("neotree-fs-refactor.cache")
    local use_optimized = config and config.cache and config.cache.method == "optimized"

    for _, result in ipairs(results) do
      if result.success then
        vim.schedule(function()
          if use_optimized then
            local scanner = require("neotree-fs-refactor.cache.scanner_optimized")
            scanner.scan_single_file_optimized(result.file, cache._current_cache)
          else
            cache.update_single_file(result.file)
          end
        end)
      end
    end
  end
end

--- Trigger a full rescan of the current directory
---@param use_optimized boolean|nil Use optimized scanner (default: true)
---@return nil
function M.rescan_directory(use_optimized)
  if use_optimized == nil then
    use_optimized = true
  end

  local cwd = vim.fn.getcwd()
  logger.info("Triggering full directory rescan: " .. cwd)

  local cache = require("neotree-fs-refactor.cache")
  local new_cache = cache.create_cache(cwd)

  if use_optimized then
    local scanner = require("neotree-fs-refactor.cache.scanner_optimized")
    scanner.scan_directory_optimized(cwd, new_cache, function()
      logger.info("Directory rescan complete (optimized)")
    end)
  else
    local scanner = require("neotree-fs-refactor.cache.scanner_async")
    scanner.scan_directory(cwd, new_cache, function()
      logger.info("Directory rescan complete")
    end)
  end
end


return M
