---@module 'neotree-fs-refactor.@types'

---@class Neotree.FSRefactor.Result
---@field files_changed number Number of files changed
---@field lines_changed number Total lines changed
---@field buffers_updated number Number of buffers updated

---@class Neotree.FSRefactor.Config
---@field enabled? boolean Whether the plugin is enabled
---@field auto_save? boolean Auto-save buffers after refactoring
---@field notify_on_refactor? boolean Show notification after refactoring
---@field ignore_patterns? string[] Patterns to ignore (e.g., "node_modules/**")
---@field file_types? table<string, boolean> File types to process (only lua/python/typescript/javascript(react) currently have a pattern replacer)
---@field max_file_size? number Maximum file size in bytes to process
---@field debounce_ms? number Debounce delay for file operations

-- Return empty table (type definitions only)
return {}
