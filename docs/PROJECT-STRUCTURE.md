# Project Structure

## Directory Layout

```
neotree-fs-refactor.nvim/
├── lua/
│   └── neotree-fs-refactor/
│       ├── init.lua                 # Plugin entry point & setup
│       ├── core/
│       │   ├── event_handlers.lua   # Neo-tree event integration
│       │   └── refactor.lua         # Core refactoring logic
│       └── utils/
│           ├── scanner.lua          # File reference scanner
│           ├── path.lua             # Path manipulation utilities
│           └── helpers.lua          # General helper functions
├── plugin/
│   └── neotree-fs-refactor.lua      # Auto-load plugin file
├── doc/
│   └── neotree-fs-refactor.txt      # Vim help documentation
├── docs/
│   ├── Arch&Coding-Regeln.md        # Architecture & coding guidelines
│   ├── Checklist.md                 # Development checklist
│   └── STRUCTURE.md                 # This file
├── README.md                        # User documentation
├── LICENSE                          # MIT License
└── .github/
    └── workflows/
        └── ci.yml                   # CI/CD configuration
```

## Module Dependencies

```
init.lua
  └─> core/event_handlers.lua
        ├─> core/refactor.lua
        │     ├─> utils/scanner.lua
        │     │     └─> utils/path.lua
        │     └─> utils/path.lua
        └─> utils/helpers.lua
              └─> utils/path.lua (indirect)
```

## Module Responsibilities

### `lua/neotree-fs-refactor/init.lua`
- Plugin setup and configuration
- Configuration validation
- Health check integration
- Entry point for user

### `lua/neotree-fs-refactor/core/event_handlers.lua`
- Registers neo-tree event handlers
- Debounces file operations
- Coordinates between neo-tree and refactor module
- Error handling for events

### `lua/neotree-fs-refactor/core/refactor.lua`
- Core refactoring logic
- Updates references in buffers
- Updates references in files on disk
- Language-specific pattern matching
- Statistics tracking

### `lua/neotree-fs-refactor/utils/scanner.lua`
- File reference detection
- Ripgrep integration
- Fallback Lua-based scanning
- Pattern building for different languages

### `lua/neotree-fs-refactor/utils/path.lua`
- Path normalization
- Module name conversion (Lua, Python, TS/JS)
- Relative path calculations
- File type detection

### `lua/neotree-fs-refactor/utils/helpers.lua`
- User notifications
- Table utilities
- String utilities
- Debouncing utilities

## Require Paths

### Correct Import Statements

All modules should use the full plugin namespace:

```lua
-- In init.lua
local event_handlers = require("neotree-fs-refactor.core.event_handlers")

-- In core/event_handlers.lua
local refactor = require("neotree-fs-refactor.core.refactor")
local utils = require("neotree-fs-refactor.utils.helpers")

-- In core/refactor.lua
local scanner = require("neotree-fs-refactor.utils.scanner")
local path_utils = require("neotree-fs-refactor.utils.path")

-- In utils/scanner.lua
local path_utils = require("neotree-fs-refactor.utils.path")

-- In utils/helpers.lua
-- No internal dependencies (leaf module)
```

### Why Full Paths?

1. **Clarity**: Makes module origin obvious
2. **Consistency**: Same pattern across all files
3. **No Ambiguity**: Avoids conflicts with other plugins
4. **Lua Standards**: Follows Neovim plugin conventions

## Data Flow

### Rename/Move Operation

```
Neo-tree Event
    │
    ↓
event_handlers.on_file_renamed()
    │
    ├─> Debounce (100ms default)
    │
    ↓
refactor.rename_references()
    │
    ├─> Update open buffers
    │   └─> refactor.update_buffers()
    │         └─> Pattern matching per filetype
    │
    ├─> Scan project files
    │   └─> scanner.find_files_with_references()
    │         ├─> Use ripgrep (if available)
    │         └─> Use Lua scanning (fallback)
    │
    ├─> Update files on disk
    │   └─> refactor.update_file_on_disk()
    │
    └─> Report results
        └─> helpers.notify_refactor_result()
```

### Delete Operation

```
Neo-tree Event
    │
    ↓
event_handlers.on_file_deleted()
    │
    ├─> Debounce (100ms default)
    │
    ↓
refactor.delete_references()
    │
    ├─> Scan for remaining references
    │   └─> scanner.find_files_with_references()
    │
    └─> Warn user if references exist
        └─> helpers.notify_refactor_result()
```

## Configuration Flow

```
User Config
    │
    ↓
init.setup(opts)
    │
    ├─> Merge with defaults
    │
    ├─> Validate configuration
    │
    ├─> Check dependencies
    │
    └─> Initialize event handlers
        └─> event_handlers.setup(config)
              └─> Register neo-tree events
```

## Error Handling Strategy

### Layers of Safety

1. **Entry Point** (`init.lua`)
   - Validates neo-tree existence
   - Wraps setup in pcall
   - Provides user feedback

2. **Event Handlers** (`event_handlers.lua`)
   - Validates event arguments
   - Wraps refactor calls in pcall
   - Provides error notifications

3. **Core Logic** (`refactor.lua`)
   - Validates paths
   - Guards buffer operations
   - Safe file I/O

4. **Utilities**
   - Input validation
   - Graceful degradation
   - Fallback mechanisms

### Example Error Path

```lua
-- init.lua
local ok, err = pcall(function()
  require("neotree-fs-refactor.core.event_handlers").setup(config)
end)

if not ok then
  vim.notify("Setup failed: " .. err, vim.log.levels.ERROR)
end
```

## Performance Considerations

### Hot Paths (Optimized)

1. **Buffer Updates**
   - In-memory operations
   - Direct API calls
   - No I/O blocking

2. **Ripgrep Integration**
   - Native binary
   - Parallel execution
   - Filtered results

### Cold Paths (Acceptable)

1. **Lua Scanning**
   - Fallback only
   - Small projects OK
   - Limited by I/O

2. **File Writing**
   - Infrequent operation
   - User-initiated
   - Progress feedback

### Optimization Strategies

1. **Debouncing**: Prevent duplicate operations
2. **Lazy Loading**: Load modules on demand
3. **Caching**: Reuse compiled patterns
4. **Filtering**: Respect ignore patterns early

## Testing Strategy

### Unit Tests (Planned)

```
tests/
├── core/
│   ├── refactor_spec.lua
│   └── event_handlers_spec.lua
└── utils/
    ├── scanner_spec.lua
    ├── path_spec.lua
    └── helpers_spec.lua
```

### Integration Tests (Planned)

```
tests/integration/
├── rename_scenario_spec.lua
├── move_scenario_spec.lua
└── delete_scenario_spec.lua
```

### Manual Testing Checklist

- [ ] Rename single file
- [ ] Rename directory
- [ ] Move file to different directory
- [ ] Delete file with references
- [ ] Multiple simultaneous operations
- [ ] Large project performance
- [ ] Edge cases (symlinks, special chars)

## Compliance with Coding Guidelines

This project follows the guidelines in `docs/Arch&Coding-Regeln.md`:

### ✅ Implemented

- [x] Single Responsibility Principle
- [x] Error handling with pcall
- [x] Type annotations (@class, @param, @return)
- [x] Module documentation (@module, @brief, @description)
- [x] No global state
- [x] Pure functions where possible
- [x] Local helper functions
- [x] Debouncing for performance
- [x] Path normalization
- [x] Cross-platform support (POSIX & Windows)

### 📋 Checklist Items

Refer to `docs/Checklist.md` for detailed review items.

## Future Enhancements

### Planned Features

1. **AST-Based Refactoring**
   - Use treesitter for accurate parsing
   - Handle dynamic imports
   - Better scope analysis

2. **LSP Integration**
   - Leverage language servers
   - Semantic understanding
   - Cross-reference resolution

3. **Undo/Redo Support**
   - Save refactor history
   - Atomic operations
   - Rollback capability

4. **Configuration Presets**
   - Language-specific defaults
   - Project templates
   - Shareable configs

5. **Performance Dashboard**
   - Operation metrics
   - Bottleneck identification
   - Optimization suggestions

### Community Contributions Welcome

- Additional language support
- Performance improvements
- Test coverage
- Documentation enhancements
- Bug fixes

## References

- [Neo-tree Events Documentation](https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/doc/neo-tree.txt)
- [Neovim Plugin Development](https://neovim.io/doc/user/lua-guide.html)
- [LuaLS Annotations](https://luals.github.io/wiki/annotations/)
