---@module 'neotree-fs-refactor.@types'

-- #####################################################################
-- Core Configuration Types

---@class Neotree.FSRefactor.Result
---@field files_changed number Number of files changed
---@field lines_changed number Total lines changed
---@field buffers_updated number Number of buffers updated

---@class Neotree.FSRefactor.Config
---@field enabled? boolean Whether the plugin is enabled
---@field auto_save? boolean Auto-save buffers after refactoring
---@field notify_on_refactor? boolean Show notification after refactoring
---@field ignore_patterns? string[] Patterns to ignore (e.g., "node_modules/**")
---@field file_types? table<string, boolean> File types to process
---@field max_file_size? number Maximum file size in bytes to process
---@field debounce_ms? number Debounce delay for file operations
---@field path? string path to cache file
---@field cache? Neotree.FSRefactor.CacheConfig Cache system configuration
---@field refactor? Neotree.FSRefactor.RefactorBehaviorConfig Refactoring behavior settings
---@field ui? Neotree.FSRefactor.UIConfig User interface configuration
---@field performance? Neotree.FSRefactor.PerformanceConfig Performance tuning options

---@class Neotree.FSRefactor.CacheConfig
---@field enabled? boolean Enable/disable cache system
---@field method? "async_lua"|"optimized"|"native_c" Cache building method
---@field path? string Path to cache directory
---@field auto_update_on_cwd_change? boolean Update cache on CWD change
---@field cleanup_after_days? integer Days before cleaning up unused cache
---@field incremental_updates? boolean Enable incremental cache updates

---@class Neotree.FSRefactor.RefactorBehaviorConfig
---@field confirm_before_write? boolean Ask for confirmation before writing
---@field dry_run? boolean Show changes without applying them
---@field show_picker? boolean Show interactive picker for changes
---@field auto_select_all? boolean Automatically select all changes
---@field fallback_to_ripgrep? boolean Use ripgrep when cache unavailable

---@class Neotree.FSRefactor.UIConfig
---@field picker? "telescope"|"fzf-lua" Picker backend
---@field progress_notifications? boolean Show progress notifications
---@field log_level? "debug"|"info"|"warn"|"error" Logging level

---@class Neotree.FSRefactor.PerformanceConfig
---@field max_files_per_scan? integer Maximum files to scan in one pass
---@field debounce_ms? integer Debounce time for file watching
---@field parallel_workers? integer Number of parallel workers for scanning

-- #####################################################################
-- Cache Types

--- A single require statement found in a file
---@class Neotree.FSRefactor.CacheEntry
---@field line integer Line number where the require is found (hint, not authoritative)
---@field require_path string Lua module path (e.g., "testfs.rem.da")

--- Persistent cache structure for a directory
---@class Neotree.FSRefactor.CacheData
---@field version string Cache format version (e.g., "1.0.0")
---@field cwd string Current working directory this cache represents
---@field last_updated integer Unix timestamp of last cache update
---@field last_accessed integer Unix timestamp of last cache access
---@field entries table<string, Neotree.FSRefactor.CacheEntry[]> Map of file paths to require entries

-- #####################################################################
-- Refactoring Types

---@class Neotree.FSRefactor.RequireChange
--- Represents a single require statement that needs to be updated
---@field file string Absolute file path containing the require
---@field line integer Line number where the require is located (may be adjusted during verification)
---@field old_require string Old module path (e.g., "testfs.rem.da")
---@field new_require string New module path (e.g., "testfs.remolus.da")
---@field old_line_content string|nil Original line content before change
---@field new_line_content string|nil Updated line content after change

---@class Neotree.FSRefactor.UpdateResult
--- Result of applying changes to a file
---@field success boolean Whether the update succeeded
---@field file string File path that was updated
---@field changes_applied integer Number of changes successfully applied
---@field error string|nil Error message if the update failed

-- #####################################################################
-- UI Types

---@class Neotree.FSRefactor.PickerEntry
--- Entry displayed in the picker UI
---@field value Neotree.FSRefactor.RequireChange The underlying change object
---@field display string Formatted display string for the picker
---@field ordinal string String used for sorting/filtering
---@field path string File path for preview
---@field lnum integer Line number for preview

-- #####################################################################
-- Utility Types

---@alias Neotree.FSRefactor.LogLevel "debug"|"info"|"warn"|"error"
--- Log level for the logging system

---@alias Neotree.FSRefactor.PathMode "absolute"|"relative"|"cwd"|"home"
--- Path display modes

-- Return empty table (type definitions only)
return {}
