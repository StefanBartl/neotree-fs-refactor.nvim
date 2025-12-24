# neotree-fs-refactor.nvim - Project Structure

## Table of content

  - [Complete File Tree](#complete-file-tree)
  - [Module Overview](#module-overview)
    - [Core Modules (lua/neotree_fs_refactor/)](#core-modules-luaneotree_fs_refactor)
      - [1. **init.lua** (Main Entry Point)](#1-initlua-main-entry-point)
      - [2. **config.lua** (Configuration Management)](#2-configlua-configuration-management)
      - [3. **utils.lua** (Utility Functions)](#3-utilslua-utility-functions)
      - [4. **lsp.lua** (LSP Integration)](#4-lsplua-lsp-integration)
      - [5. **fallback.lua** (Fallback Search)](#5-fallbacklua-fallback-search)
      - [6. **orchestrator.lua** (Workflow Orchestration)](#6-orchestratorlua-workflow-orchestration)
      - [7. **neotree.lua** (Neo-tree Integration)](#7-neotreelua-neo-tree-integration)
      - [8. **ui/preview.lua** (Preview Window)](#8-uipreviewlua-preview-window)
      - [9. **health.lua** (Health Check)](#9-healthlua-health-check)
      - [10. **@types/init.lua** (Type Definitions)](#10-typesinitlua-type-definitions)
  - [Data Flow](#data-flow)
    - [Typical Refactoring Flow](#typical-refactoring-flow)
  - [Design Principles Applied](#design-principles-applied)
    - [From Arch&Coding-Regeln.md:](#from-archcoding-regelnmd)
  - [Configuration Philosophy](#configuration-philosophy)
    - [Lazy Resolution Pattern](#lazy-resolution-pattern)
  - [Error Handling Strategy](#error-handling-strategy)
    - [Three-Layer Approach:](#three-layer-approach)
  - [Testing Strategy](#testing-strategy)
    - [Test Coverage:](#test-coverage)
    - [Test Framework:](#test-framework)
  - [Future Enhancements](#future-enhancements)
    - [Potential Improvements:](#potential-improvements)
  - [Summary](#summary)

---

## Complete File Tree

```
neotree_fs_refactor.nvim/
├── lua/
│   └── neotree_fs_refactor/
│       ├── @types/
│       │   └── init.lua              # Type definitions (LuaLS annotations)
│       ├── ui/
│       │   └── preview.lua           # Preview window implementation
│       ├── config.lua                # Configuration management
│       ├── utils.lua                 # Utility functions
│       ├── lsp.lua                   # LSP integration
│       ├── fallback.lua              # Fallback text search
│       ├── orchestrator.lua          # Refactoring workflow
│       ├── neotree.lua               # Neo-tree hooks
│       ├── health.lua                # Health check
│       └── init.lua                  # Main entry point
├── plugin/
│   └── neotree_fs_refactor.lua       # Plugin specification
├── tests/
│   ├── test_utils.lua                # Testing framework
│   ├── config_test.lua               # Config tests
│   ├── utils_test.lua                # Utils tests
│   └── integration_test.lua          # Integration tests
├── examples/
│   └── configurations.lua            # Example configurations
├── docs/
│   ├── Arch&Coding-Regeln.md        # Architecture & coding rules
│   └── Checklist.md                 # Development checklist
├── README.md                         # User documentation
├── CONTRIBUTING.md                   # Contributor guide
└── LICENSE                           # MIT License
```

---

## Module Overview

### Core Modules (lua/neotree_fs_refactor/)

#### 1. **init.lua** (Main Entry Point)
- **Responsibility**: Plugin initialization, user commands, public API
- **Key Functions**:
  - `setup(opts)`: Initialize plugin with configuration
  - `refactor_path(old, new)`: Manual refactoring trigger
  - `show_info()`: Display plugin status
  - `reload()`: Reload configuration
- **Dependencies**: All other modules
- **Public**: Yes

---

#### 2. **config.lua** (Configuration Management)
- **Responsibility**: Configuration storage, validation, access
- **Key Functions**:
  - `setup(opts)`: Initialize config with user options
  - `get(key)`: Retrieve config value (lazy resolution)
  - `validate()`: Validate configuration
  - `is_lsp_enabled()`, `should_auto_apply()`, etc.: Config checks
- **Design Pattern**: Metatable-based lazy initialization
- **Dependencies**: None (foundation layer)
- **Public**: Yes (internal API)

---

#### 3. **utils.lua** (Utility Functions)
- **Responsibility**: Pure utility functions for paths, buffers, validation
- **Key Functions**:
  - Path operations: `normalize_path()`, `to_absolute()`, `basename()`, `dirname()`, `relative_path()`
  - File system: `path_exists()`, `is_directory()`, `get_file_size_kb()`
  - Validation: `should_ignore()`, `is_valid_buffer()`, `is_valid_window()`
  - Buffer operations: `get_buf_lines()`, `set_buf_lines()`
  - Helpers: `escape_pattern()`, `debounce()`, `deep_copy()`, `merge_tables()`
- **Design Pattern**: Pure functions, no side effects
- **Dependencies**: None (foundation layer)
- **Public**: Yes (internal API)

---

#### 4. **lsp.lua** (LSP Integration)
- **Responsibility**: Communicate with LSP servers for semantic refactoring
- **Key Functions**:
  - `collect_edits(operation)`: Request edits from all LSP clients
  - `apply_edits(lsp_result)`: Apply LSP edits to buffers
- **LSP Methods Used**:
  - `workspace/willRenameFiles`: Request rename edits
  - `workspace/applyEdit`: Apply workspace edits
- **Dependencies**: config, utils
- **Public**: Yes (internal API)

---

#### 5. **fallback.lua** (Fallback Search)
- **Responsibility**: Text-based search when LSP unavailable
- **Key Functions**:
  - `search(operation)`: Perform text search for path references
  - `apply_edits(fallback_result)`: Apply fallback edits
- **Search Methods**:
  - Ripgrep (fast, external)
  - Native Lua (slower, no dependencies)
- **Dependencies**: config, utils
- **Public**: Yes (internal API)

---

#### 6. **orchestrator.lua** (Workflow Orchestration)
- **Responsibility**: Coordinate LSP and fallback phases, create execution plans
- **Key Functions**:
  - `create_plan(operation)`: Create refactoring plan
  - `execute_plan(plan, skip_review)`: Execute plan
  - `get_plan_summary(plan)`: Get statistics
- **Workflow**:
  1. Validate operation
  2. Phase 1: Collect LSP edits
  3. Phase 2: Collect fallback edits (if enabled)
  4. Create unified plan
- **Dependencies**: config, lsp, fallback, utils
- **Public**: Yes (internal API)

---

#### 7. **neotree.lua** (Neo-tree Integration)
- **Responsibility**: Hook into Neo-tree events, trigger refactoring
- **Key Functions**:
  - `on_renamed(event)`: Handle file/folder rename
  - `on_moved(event)`: Handle file/folder move
  - `on_deleted(event)`: Handle file/folder delete
  - `register_hooks()`: Subscribe to Neo-tree events
- **Neo-tree Events**:
  - `FILE_RENAMED`
  - `FILE_MOVED`
  - `FILE_DELETED`
- **Dependencies**: config, orchestrator, preview, utils
- **Public**: No (internal, called by Neo-tree)

---

#### 8. **ui/preview.lua** (Preview Window)
- **Responsibility**: Interactive change preview, user confirmation
- **Key Functions**:
  - `show_preview(plan, callback)`: Display preview window
  - `close_preview()`: Close and cleanup
  - `is_preview_open()`: Check status
- **UI Features**:
  - Floating window with diff-style display
  - Keymaps: `<CR>` (confirm), `<Esc>` (cancel)
  - Syntax highlighting
- **Dependencies**: config, utils
- **Public**: Yes (internal API)

---

#### 9. **health.lua** (Health Check)
- **Responsibility**: Diagnostic checks for `:checkhealth`
- **Key Functions**:
  - `check()`: Run all health checks
- **Checks**:
  - Neovim version
  - Neo-tree installation
  - Plugin modules
  - LSP capabilities
  - Fallback tools
  - Configuration validation
- **Dependencies**: All modules (for validation)
- **Public**: Yes (called by Neovim)

---

#### 10. **@types/init.lua** (Type Definitions)
- **Responsibility**: LuaLS type annotations
- **Key Types**:
  - `Neotree.FSRefactor.FSOperation`: Filesystem operation
  - `Neotree.FSRefactor.ChangePlan`: Complete refactoring plan
  - `Neotree.FSRefactor.LSPResult`, `Neotree.FSRefactor.FallbackResult`: Phase results
  - `Neotree.FSRefactor.Config`: Configuration schema
  - `Neotree.FSRefactor.PreviewState`: UI state
  - `Neotree.FSRefactor.ApplyResult`: Execution result
- **Dependencies**: None
- **Public**: No (annotations only)

---

## Data Flow

### Typical Refactoring Flow

```
1. Neo-tree Event
   └─> neotree.lua::on_renamed()
       │
2. Create Operation
   └─> orchestrator.lua::create_plan()
       │
3. Phase 1: LSP
   └─> lsp.lua::collect_edits()
       ├─> Request workspace/willRenameFiles
       └─> Parse WorkspaceEdit responses
       │
4. Phase 2: Fallback
   └─> fallback.lua::search()
       ├─> Build search patterns
       ├─> Execute ripgrep/native search
       └─> Convert to edits
       │
5. Create Plan
   └─> orchestrator.lua (combine results)
       │
6. Preview (optional)
   └─> ui/preview.lua::show_preview()
       ├─> User confirms/cancels
       └─> Callback with decision
       │
7. Execute
   └─> orchestrator.lua::execute_plan()
       ├─> lsp.lua::apply_edits()
       └─> fallback.lua::apply_edits()
       │
8. Complete
   └─> Notify user of results
```

---

## Design Principles Applied

### From Arch&Coding-Regeln.md:

1. **Sicherheitsprinzipien** ✅
   - All API calls wrapped in `pcall`
   - Type guards before operations
   - Buffer/window validation
   - Structured error handling

2. **Modularisierung** ✅
   - Single responsibility per module
   - Pure functions where possible
   - No global state
   - Explicit dependencies

3. **Buffer/Window Management** ✅
   - Always validate handles
   - Check `is_valid` before use
   - Proper cleanup

4. **Dokumentation** ✅
   - Comprehensive LuaLS annotations in @types/
   - Module headers with @brief, @description
   - Function documentation with @param, @return
   - @see links between related modules

5. **Testbarkeit** ✅
   - Dependency injection
   - Pure functions
   - No hardcoded state
   - Test framework included

6. **Performance** ✅
   - Lazy initialization (config metatable)
   - Table pre-allocation
   - Efficient string operations
   - Debounced I/O

---

## Configuration Philosophy

### Lazy Resolution Pattern

```lua
-- Config uses metatable for lazy field initialization
local config_mt = {
  __index = function(tbl, key)
    local default_val = defaults[key]

    if type(default_val) == "table" then
      local nested = setmetatable({}, config_mt)
      rawset(tbl, key, nested)
      return nested
    end

    return default_val
  end
}
```

**Benefits**:
- Only initialize fields when accessed
- Saves memory for unused config options
- Allows dynamic default resolution
- Supports deep nesting

---

## Error Handling Strategy

### Three-Layer Approach:

1. **Validation Layer** (Before operation)
   ```lua
   local valid, err = validate_operation(operation)
   if not valid then
     return nil, err
   end
   ```

2. **Protected Execution** (During operation)
   ```lua
   local ok, result = pcall(risky_function, args)
   if not ok then
     results.errors[#results.errors + 1] = tostring(result)
   end
   ```

3. **Result Reporting** (After operation)
   ```lua
   return {
     success = #errors == 0,
     applied_count = count,
     failed_count = failures,
     errors = errors, -- Structured error objects
   }
   ```

---

## Testing Strategy

### Test Coverage:

1. **Unit Tests**
   - config_test.lua: Configuration validation
   - utils_test.lua: Utility functions

2. **Integration Tests**
   - integration_test.lua: Module loading, health checks

3. **Manual Testing**
   - Real Neo-tree operations
   - Different LSP servers
   - Various file types

---

### Test Framework:
- Custom lightweight framework in `test_utils.lua`
- Assertion helpers
- Suite runner with reporting

---

## Future Enhancements

### Potential Improvements:

1. **Undo Stack Integration**
   - Track changes for rollback
   - Integration with Neovim undo

2. **Batch Operations**
   - Multiple renames at once
   - Folder-wide refactoring

3. **Custom Rules**
   - User-defined pattern matching
   - Project-specific ignore rules

4. **Better Diff Preview**
   - Side-by-side diff view
   - Syntax highlighting in preview

5. **Performance Optimizations**
   - Parallel search
   - Incremental updates
   - Background processing

---

## Summary

This plugin provides a **production-ready**, **well-architected** solution for automatic refactoring when renaming/moving files in Neo-tree. It follows best practices from `Arch&Coding-Regeln.md`, includes comprehensive testing, and is designed for extensibility and maintainability.

**Key Strengths**:
- Safe by default (preview, validation, error handling)
- Flexible (LSP + fallback, configurable)
- Well-documented (inline annotations, README, CONTRIBUTING)
- Testable (dependency injection, pure functions)
- Performant (lazy loading, efficient algorithms)

---
