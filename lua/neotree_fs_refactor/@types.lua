---@module 'neotree_fs_refactor.@types'
---@brief Core type definitions for neotree-fs-refactor
---@description
--- Central type definitions used across the plugin.
--- Separates annotation overhead from source code for better readability.

-- #####################################################################
-- Common Types

---@alias Neotree.FSRefactor.OperationType
--- Type of filesystem operation performed
---| "rename"    # Single file/directory rename
---| "move"      # Move to different directory
---| "delete"    # File/directory deletion

---@alias Neotree.FSRefactor.PathType
--- Type of filesystem entity
---| "file"      # Regular file
---| "directory" # Directory/folder

---@class Neotree.FSRefactor.FSOperation
--- Represents a filesystem operation from Neo-tree
---@field type Neotree.FSRefactor.OperationType Operation type
---@field old_path string Absolute path before operation
---@field new_path string|nil Absolute path after operation (nil for delete)
---@field is_directory boolean Whether the target is a directory
---@field timestamp number Operation timestamp (os.time())

---@class Neotree.FSRefactor.PathReference
--- A reference to a path found in a file
---@field file_path string Absolute path of file containing the reference
---@field line_number integer Line number (1-based)
---@field column_start integer Start column (1-based)
---@field column_end integer End column (1-based)
---@field matched_text string Original matched text
---@field context_line string Full line containing the reference

-- #####################################################################
-- LSP Types

---@class Neotree.FSRefactor.LSPEdit
--- Represents an edit from LSP workspace/willRenameFiles
---@field file_path string File to be edited
---@field changes table[] Array of TextEdit objects from LSP
---@field lsp_name string Name of LSP that provided the edit

---@class Neotree.FSRefactor.LSPResult
--- Result from LSP refactoring phase
---@field success boolean Whether LSP phase succeeded
---@field edits Neotree.FSRefactor.LSPEdit[] Collected edits from all LSPs
---@field errors string[] Any errors encountered
---@field servers_contacted string[] List of LSP servers that responded

-- #####################################################################
-- Fallback Search Types

---@class Neotree.FSRefactor.SearchPattern
--- Pattern for text-based fallback search
---@field pattern string Lua pattern or literal string
---@field is_regex boolean Whether pattern is regex
---@field file_types string[]|nil Restrict to specific filetypes (nil = all)
---@field exclude_patterns string[]|nil Patterns to exclude from search

---@class Neotree.FSRefactor.FallbackEdit
--- Edit discovered via text search
---@field file_path string File to be edited
---@field line_number integer Line to modify
---@field old_text string Text to replace
---@field new_text string Replacement text
---@field confidence "high"|"medium"|"low" Confidence in this edit

---@class Neotree.FSRefactor.FallbackResult
--- Result from fallback text search phase
---@field success boolean Whether search completed
---@field edits Neotree.FSRefactor.FallbackEdit[] Found edits
---@field files_scanned integer Number of files searched
---@field matches_found integer Total matches found
---@field errors string[] Any errors during search

-- #####################################################################
-- Change Plan Types

---@class Neotree.FSRefactor.ChangePlan
--- Complete plan of all changes to be applied
---@field operation Neotree.FSRefactor.FSOperation Original filesystem operation
---@field lsp_result Neotree.FSRefactor.LSPResult Results from LSP phase
---@field fallback_result Neotree.FSRefactor.FallbackResult|nil Results from fallback phase (optional)
---@field created_at number Timestamp when plan was created
---@field reviewed boolean Whether user has reviewed the plan

---@class Neotree.FSRefactor.ApplyResult
--- Result of applying a change plan
---@field success boolean Whether all changes applied successfully
---@field applied_count integer Number of edits successfully applied
---@field failed_count integer Number of edits that failed
---@field errors table[] Detailed error information
---@field duration_ms number Time taken to apply changes

-- #####################################################################
-- Configuration Types

---@class Neotree.FSRefactor.Config
--- Plugin configuration
---@field enable_lsp? boolean Enable LSP-based refactoring
---@field enable_fallback? boolean Enable text-based fallback search
---@field auto_apply? boolean Auto-apply changes without review
---@field preview_changes? boolean Show preview before applying
---@field notify_level? "error"|"warn"|"info"|"debug" Notification verbosity
---@field ignore_patterns? string[] Patterns to ignore (like .gitignore)
---@field file_type_filters? string[]|nil Restrict operations to specific filetypes
---@field max_file_size_kb? integer Skip files larger than this
---@field timeout_ms? integer Timeout for LSP operations
---@field fallback? Neotree.FSRefactor.SearchFallbackConfig Fallback search configuration

---@class Neotree.FSRefactor.SearchFallbackConfig
--- Configuration for text-based fallback search
---@field enabled boolean Enable fallback search
---@field tool? "ripgrep"|"native" Search tool to use
---@field case_sensitive? boolean Case-sensitive matching
---@field whole_word? boolean Match whole words only
---@field confidence_threshold? "high"|"medium"|"low" Minimum confidence to include

-- #####################################################################
-- UI Types

---@class Neotree.FSRefactor.PreviewItem
--- Single item in change preview
---@field file_path string File being modified
---@field edit_type "lsp"|"fallback" Source of edit
---@field old_content string Original content
---@field new_content string New content
---@field line_number integer Line being changed
---@field confidence string|nil Confidence level (fallback only)

---@class Neotree.FSRefactor.PreviewState
--- State of preview window
---@field items Neotree.FSRefactor.PreviewItem[] All preview items
---@field current_index integer Currently selected item
---@field buf integer|nil Preview buffer handle
---@field win integer|nil Preview window handle
---@field confirmed boolean Whether user confirmed changes

-- #####################################################################
-- Error Types

---@class Neotree.FSRefactor.Error
--- Structured error information
---@field code string Error code (e.g., "LSP_TIMEOUT", "FILE_NOT_FOUND")
---@field message string Human-readable error message
---@field context table|nil Additional context information
---@field recoverable boolean Whether operation can be retried

-- #####################################################################

return {}
