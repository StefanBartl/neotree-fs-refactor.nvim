# neotree-fs-refactor.nvim

Automatic Lua `require()` refactoring for Neo-tree file operations.

## ✨ Features

- 🔄 **Automatic Require Updates**: Automatically updates `require()` statements when files/directories are renamed in Neo-tree
- 🚀 **Smart Caching**: Persistent cache system for fast lookups across Neovim sessions
- 🔍 **Interactive Picker**: Review and select which requires to update via Telescope/FZF-Lua
- ⚡ **Async Scanning**: Non-blocking directory scanning using libuv
- 🌳 **Hierarchical Cache**: Parent directory caches automatically apply to subdirectories
- 🧹 **Auto Cleanup**: Automatic removal of stale cache files
- 🎯 **Pattern Matching**: Supports multiple require() syntax styles

## 📦 Installation

### lazy.nvim

```lua
{
  "StefanBartl/neotree-fs-refactor.nvim",
  dependencies = {
    "nvim-neo-tree/neo-tree.nvim",
    "nvim-telescope/telescope.nvim", -- or "ibhagwan/fzf-lua"
  },
  config = function()
    require("neotree-fs-refactor").setup({
      -- Configuration (see below)
    })
  end,
}
```

### packer.nvim

```lua
use {
  "StefanBartl/neotree-fs-refactor.nvim",
  requires = {
    "nvim-neo-tree/neo-tree.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("neotree-fs-refactor").setup()
  end,
}
```

## ⚙️ Configuration

### Default Configuration

```lua
require("neotree-fs-refactor").setup({
  -- Cache System
  cache = {
    enabled = true,                    -- Enable cache system
    method = "optimized",              -- "async_lua" | "optimized" | "native_c" (future)
    path = vim.fn.stdpath("cache") .. "/neotree-fs-refactor",
    auto_update_on_cwd_change = false, -- Auto-scan on :cd
    cleanup_after_days = 7,            -- Delete caches older than N days
    incremental_updates = true,        -- Update cache on BufWritePost
  },

  -- Refactoring Behavior
  refactor = {
    confirm_before_write = true,       -- Ask before applying changes
    dry_run = false,                   -- Only show what would change
    show_picker = true,                -- Show interactive picker
    auto_select_all = false,           -- Pre-select all changes
    fallback_to_ripgrep = true,        -- Use ripgrep if no cache
  },

  -- UI
  ui = {
    picker = "telescope",              -- "telescope" | "fzf-lua"
    progress_notifications = true,     -- Show progress messages
    log_level = "info",                -- "debug" | "info" | "warn" | "error"
  },

  -- Performance
  performance = {
    max_files_per_scan = 10000,        -- Safety limit
    debounce_ms = 500,                 -- Debounce for file watching
    parallel_workers = 4,              -- Async workers (unused currently)
  },
})
```

## 🔗 Neo-tree Integration

Add the following to your Neo-tree configuration:

```lua
require("neo-tree").setup({
  event_handlers = {
    {
      event = "file_renamed",
      handler = function(args)
        require("neotree-fs-refactor.neotree_integration").on_rename(
          args.source,
          args.destination
        )
      end,
    },
    {
      event = "file_moved",
      handler = function(args)
        require("neotree-fs-refactor.neotree_integration").on_move(
          args.source,
          args.destination
        )
      end,
    },
  },
})
```

Or use the helper function:

```lua
local refactor_config = require("neotree-fs-refactor").get_neotree_config()

require("neo-tree").setup({
  event_handlers = vim.tbl_extend(
    "force",
    refactor_config.event_handlers,
    -- your other handlers
    {}
  ),
})
```

## 🚀 Usage

### Automatic (with Neo-tree)

1. Rename a file or directory in Neo-tree
2. The plugin automatically:
   - Finds all `require()` statements referencing the old path
   - Shows an interactive picker (if enabled)
   - Updates the files

### Manual Commands

```vim
:RefactorRescan          " Manually rescan current directory
:RefactorCacheStats      " Show cache statistics
```

### Programmatic API

```lua
-- Manual refactor
require("neotree-fs-refactor").refactor(old_path, new_path)

-- Rescan directory
require("neotree-fs-refactor").rescan()

-- Check cache
if require("neotree-fs-refactor").has_cache() then
  local stats = require("neotree-fs-refactor").get_cache_stats()
  print(vim.inspect(stats))
end
```

## 📋 Workflow Example

### Before Rename

```
lua/
  testfs/
    rem/
      da.lua
    init.lua    -- require("testfs.rem.da")
```

### Rename Directory: `rem` → `remolus`

### Picker Shows

```
init.lua:3 | testfs.rem.da → testfs.remolus.da
```

- Press `<Tab>` to toggle selection
- Press `<S-A>` to select all
- Press `<CR>` to confirm

### After Rename

```lua
-- init.lua
local remda = require("testfs.remolus.da")  -- ✓ Updated!
```

## 🎯 Supported Require Patterns

```lua
require("module.path")
require "module.path"
require('module.path')
require 'module.path'
```

## 🚀 Performance

### Scanner Methods

The plugin offers two scanning methods:

1. **`async_lua`** (Default fallback)
   - Pure Lua implementation
   - Cross-platform
   - Good for small to medium projects

2. **`optimized`** (Recommended - Default)
   - Batched file I/O
   - Compiled regex patterns
   - String operation optimizations
   - **2-3x faster than standard scanner**
   - Suitable for large projects

### Benchmark Results

Tested on 500 Lua files with 20 requires each:

| Method     | Mean Time | Speedup |
|------------|-----------|---------|
| async_lua  | 2.4s      | 1.0x    |
| optimized  | 0.9s      | 2.7x    |

Run your own benchmarks:

```lua
require("tests.benchmark").quick()  -- Quick test
require("tests.benchmark").full()   -- Comprehensive test
```

## 🧪 Testing

### Run Tests

```bash
# All tests
./tests/run_tests.sh

# With benchmarks
./tests/run_tests.sh benchmark
```

### Test Coverage

- ✅ Unit tests (path utils, require finder, cache)
- ✅ Integration tests (full refactoring workflow)
- ✅ Performance benchmarks
- ✅ CI/CD pipeline (GitHub Actions)

## 🐛 Troubleshooting

### Cache Not Found

If refactoring is slow or falls back to ripgrep:

```vim
:RefactorRescan
```

### Check Cache Status

```vim
:RefactorCacheStats
```

### Enable Debug Logging

```lua
require("neotree-fs-refactor").setup({
  ui = {
    log_level = "debug",
  },
})
```

## 🔮 Planned Features

- [ ] Native C scanner for extreme performance
- [ ] Undo/Redo support
- [ ] Multi-root workspace support
- [ ] Custom require pattern configuration
- [ ] Git integration (detect renamed files)
- [ ] LSP integration (rename via LSP)

## 📝 License

MIT License - see [LICENSE](LICENSE)

## 🙏 Credits

Inspired by the need for better refactoring tools in Neovim.

---

**Note**: This plugin is in active development. Please report issues on GitHub!
