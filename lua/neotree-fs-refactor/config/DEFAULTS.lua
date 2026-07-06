---@module 'neotree-fs-refactor.config.DEFAULTS'
---@brief Plugin-side default configuration.
---@description
--- The single source of truth for this plugin's built-in defaults. User
--- config passed to `require("neotree-fs-refactor").setup({})` is deep-merged
--- on top of this table (see `neotree-fs-refactor.config`).

---@type Neotree.FSRefactor.Config
return {
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
  -- Only filetypes core.refactor actually has a pattern replacer for; any
  -- other filetype is silently skipped rather than warning on every save.
  file_types = {
    lua = true,
    typescript = true,
    javascript = true,
    typescriptreact = true,
    javascriptreact = true,
    python = true,
  },
  max_file_size = 1024 * 1024, -- 1MB
  debounce_ms = 100,
}
