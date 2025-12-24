---@module 'examples.configurations'
---@brief Example configurations for different use cases

-- #####################################################################
-- Example 1: Minimal Setup (Recommended for most users)
-- #####################################################################

local function minimal_setup()
  require("neotree_fs_refactor").setup()
end

-- #####################################################################
-- Example 2: TypeScript/JavaScript Project
-- #####################################################################

local function typescript_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = true,
    preview_changes = true,
    notify_level = "info",

    -- TypeScript projects often have these
    ignore_patterns = {
      ".git",
      "node_modules",
      "dist",
      "build",
      ".next",
      "coverage",
    },

    -- Focus on JS/TS files for fallback
    file_type_filters = { "javascript", "typescript", "javascriptreact", "typescriptreact" },

    -- Larger timeout for big projects
    timeout_ms = 10000,

    fallback = {
      enabled = true,
      tool = "ripgrep",
      confidence_threshold = "high", -- Strict matching for fewer false positives
    },
  })
end

-- #####################################################################
-- Example 3: Lua/Neovim Plugin Development
-- #####################################################################

local function lua_plugin_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = true,
    preview_changes = true,
    notify_level = "debug", -- More verbose for development

    ignore_patterns = {
      ".git",
      "*.so",
      "*.dll",
      ".luacache",
    },

    file_type_filters = { "lua" },

    fallback = {
      enabled = true,
      tool = "ripgrep",
      case_sensitive = true,
      whole_word = true,
      confidence_threshold = "medium",
    },
  })
end

-- #####################################################################
-- Example 4: Monorepo Setup (Multiple Languages)
-- #####################################################################

local function monorepo_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = true,
    preview_changes = true,
    notify_level = "info",

    -- Common monorepo ignore patterns
    ignore_patterns = {
      ".git",
      "node_modules",
      ".venv",
      "venv",
      "__pycache__",
      "target",
      "dist",
      "build",
      ".turbo",
      ".nx",
    },

    -- No file type restrictions - handle all languages
    file_type_filters = nil,

    -- Higher limits for large repos
    max_file_size_kb = 2048, -- 2MB
    timeout_ms = 15000, -- 15 seconds

    fallback = {
      enabled = true,
      tool = "ripgrep",
      confidence_threshold = "medium",
    },
  })
end

-- #####################################################################
-- Example 5: Performance-Focused (Large Codebase)
-- #####################################################################

local function performance_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = false, -- Disable for speed
    preview_changes = true,
    notify_level = "warn", -- Less noise
    auto_apply = false, -- Safety first

    -- Aggressive ignoring
    ignore_patterns = {
      ".git",
      "node_modules",
      "vendor",
      ".venv",
      "target",
      "*.min.js",
      "*.bundle.js",
      "dist",
      "build",
    },

    max_file_size_kb = 512, -- Skip large files
    timeout_ms = 3000, -- Fail fast
  })
end

-- #####################################################################
-- Example 6: Safe Mode (Maximum Caution)
-- #####################################################################

local function safe_mode_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = true,
    preview_changes = true, -- Always review
    auto_apply = false, -- Never auto-apply
    notify_level = "info",

    ignore_patterns = {
      ".git",
      "node_modules",
      ".venv",
      "__pycache__",
    },

    timeout_ms = 5000,

    fallback = {
      enabled = true,
      tool = "ripgrep",
      confidence_threshold = "high", -- Only very confident matches
      whole_word = true,
      case_sensitive = true,
    },
  })
end

-- #####################################################################
-- Example 7: Go Project
-- #####################################################################

local function go_project_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true, -- gopls has excellent rename support
    enable_fallback = false, -- gopls usually sufficient
    preview_changes = true,
    notify_level = "info",

    ignore_patterns = {
      ".git",
      "vendor",
      "bin",
      "*.exe",
    },

    file_type_filters = { "go" },
    timeout_ms = 8000,
  })
end

-- #####################################################################
-- Example 8: Rust Project
-- #####################################################################

local function rust_project_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true, -- rust-analyzer is excellent
    enable_fallback = false, -- Usually not needed
    preview_changes = true,
    notify_level = "info",

    ignore_patterns = {
      ".git",
      "target",
      "Cargo.lock",
    },

    file_type_filters = { "rust" },
    timeout_ms = 10000, -- rust-analyzer can be slow
  })
end

-- #####################################################################
-- Example 9: Python Project
-- #####################################################################

local function python_project_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = true, -- Python LSPs vary in quality
    preview_changes = true,
    notify_level = "info",

    ignore_patterns = {
      ".git",
      "__pycache__",
      ".venv",
      "venv",
      ".pytest_cache",
      "*.pyc",
      ".mypy_cache",
      "dist",
      "build",
      "*.egg-info",
    },

    file_type_filters = { "python" },

    fallback = {
      enabled = true,
      tool = "ripgrep",
      confidence_threshold = "medium",
    },
  })
end

-- #####################################################################
-- Example 10: Aggressive Automation (Use with Caution!)
-- #####################################################################

local function aggressive_setup()
  require("neotree_fs_refactor").setup({
    enable_lsp = true,
    enable_fallback = false, -- Only trust LSP
    preview_changes = false, -- Skip preview
    auto_apply = true, -- Auto-apply changes
    notify_level = "warn", -- Only show problems

    timeout_ms = 5000,
  })

  -- WARNING: This configuration automatically applies changes without review!
  -- Only use if you have:
  -- 1. Version control (git)
  -- 2. Automated tests
  -- 3. High confidence in your LSP setup

  vim.notify(
    "CAUTION: Aggressive auto-apply mode enabled. Changes will be applied immediately!",
    vim.log.levels.WARN
  )
end

-- #####################################################################
-- Return all examples
-- #####################################################################

return {
  minimal = minimal_setup,
  typescript = typescript_setup,
  lua_plugin = lua_plugin_setup,
  monorepo = monorepo_setup,
  performance = performance_setup,
  safe_mode = safe_mode_setup,
  go_project = go_project_setup,
  rust_project = rust_project_setup,
  python_project = python_project_setup,
  aggressive = aggressive_setup,
}
