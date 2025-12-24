# neotree-fs-refactor.nvim

Automatically refactor project-wide references when renaming or moving files in Neo-tree.

## Table of content

  - [Features](#features)
  - [Requirements](#requirements)
  - [Installation](#installation)
    - [Using [lazy.nvim](https://github.com/folke/lazy.nvim)](#using-lazynvimhttpsgithubcomfolkelazynvim)
    - [Using [packer.nvim](https://github.com/wbthomason/packer.nvim)](#using-packernvimhttpsgithubcomwbthomasonpackernvim)
  - [Configuration](#configuration)
    - [Default Configuration](#default-configuration)
    - [Minimal Configuration](#minimal-configuration)
    - [Custom Configuration Examples](#custom-configuration-examples)
      - [LSP-Only (No Fallback)](#lsp-only-no-fallback)
      - [Fallback-Only (No LSP)](#fallback-only-no-lsp)
      - [Silent Mode (Minimal Notifications)](#silent-mode-minimal-notifications)
  - [Usage](#usage)
    - [Automatic (Neo-tree Integration)](#automatic-neo-tree-integration)
    - [Manual Refactoring](#manual-refactoring)
    - [Commands](#commands)
    - [Health Check](#health-check)
  - [How It Works](#how-it-works)
    - [Phase 1: LSP Refactoring](#phase-1-lsp-refactoring)
    - [Phase 2: Fallback Search](#phase-2-fallback-search)
    - [Phase 3: Review & Apply](#phase-3-review-apply)
  - [Supported LSP Servers](#supported-lsp-servers)
  - [Preview Window](#preview-window)
    - [Keymaps (in preview)](#keymaps-in-preview)
  - [Troubleshooting](#troubleshooting)
    - [No Changes Detected](#no-changes-detected)
    - [LSP Timeout](#lsp-timeout)
    - [False Positives in Fallback](#false-positives-in-fallback)
    - [Ripgrep Not Found](#ripgrep-not-found)
  - [License](#license)
  - [Related Projects](#related-projects)
  - [Acknowledgments](#acknowledgments)

--

## Features

- **LSP Integration**: Uses LSP `workspace/willRenameFiles` for semantic refactoring
- **Fallback Search**: Text-based search using ripgrep or native Lua when LSP unavailable
- **Interactive Preview**: Review all changes before applying
- **Safe by Default**: No auto-apply without explicit confirmation
- **Multi-Language Support**: Works with any LSP server supporting file operations
- **Configurable**: Extensive configuration options for different workflows

---

## Requirements

- Neovim >= 0.9.0
- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- (Optional) [ripgrep](https://github.com/BurntSushi/ripgrep) for faster fallback search
- (Optional) LSP servers with `willRename` support (e.g., TypeScript, Lua, Go, Rust)

---

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "StefanBartl/neotree-fs-refactor.nvim",
  dependencies = {
    "nvim-neo-tree/neo-tree.nvim",
  },
  config = function()
    require("neotree-fs-refactor").setup({
      -- Configuration here (see below)
    })
  end,
}
```

---

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "StefanBartl/neotree-fs-refactor.nvim",
  requires = { "nvim-neo-tree/neo-tree.nvim" },
  config = function()
    require("neotree_fs_refactor").setup()
  end
}
```

---

## Configuration

### Default Configuration

```lua
require("neotree_fs_refactor").setup({
  -- Enable LSP-based refactoring
  enable_lsp = true,

  -- Enable text-based fallback search
  enable_fallback = true,

  -- Auto-apply changes without confirmation (not recommended)
  auto_apply = false,

  -- Show preview window before applying changes
  preview_changes = true,

  -- Notification verbosity: "error" | "warn" | "info" | "debug"
  notify_level = "info",

  -- Patterns to ignore (similar to .gitignore)
  ignore_patterns = {
    ".git",
    "node_modules",
    ".venv",
    "__pycache__",
    "target",
  },

  -- Restrict operations to specific filetypes (nil = all)
  file_type_filters = nil,

  -- Skip files larger than this (in KB)
  max_file_size_kb = 1024, -- 1MB

  -- Timeout for LSP operations (in milliseconds)
  timeout_ms = 5000,

  -- Fallback search configuration
  fallback = {
    enabled = true,

    -- Search tool: "ripgrep" | "native"
    tool = "ripgrep",

    -- Case-sensitive matching
    case_sensitive = true,

    -- Match whole words only
    whole_word = true,

    -- Minimum confidence to include: "high" | "medium" | "low"
    confidence_threshold = "medium",
  },
})
```

---

### Minimal Configuration

```lua
require("neotree_fs_refactor").setup()
```

---

### Custom Configuration Examples

#### LSP-Only (No Fallback)

```lua
require("neotree_fs_refactor").setup({
  enable_fallback = false,
  preview_changes = true,
})
```

---

#### Fallback-Only (No LSP)

```lua
require("neotree_fs_refactor").setup({
  enable_lsp = false,
  enable_fallback = true,
  fallback = {
    tool = "ripgrep",
    confidence_threshold = "high",
  },
})
```

---

#### Silent Mode (Minimal Notifications)

```lua
require("neotree_fs_refactor").setup({
  notify_level = "error",
  preview_changes = false,
  auto_apply = true, -- Use with caution!
})
```

---

## Usage

### Automatic (Neo-tree Integration)

Once configured, the plugin automatically hooks into Neo-tree's file operations:

1. **Rename a file/directory** in Neo-tree (default: `r`)
2. Plugin collects all references
3. Preview window shows proposed changes
4. Press `<CR>` to apply or `<Esc>` to cancel

---

### Manual Refactoring

You can also manually trigger refactoring:

```vim
:NeotreeRefactor /path/to/old/file.lua /path/to/new/file.lua
```

---

### Commands

- `:NeotreeRefactor <old_path> <new_path>` - Manually trigger refactoring
- `:NeotreeRefactorInfo` - Show plugin information and status
- `:NeotreeRefactorReload` - Reload configuration

---

### Health Check

Check plugin status and dependencies:

```vim
:checkhealth neotree-fs-refactor
```

---

## How It Works

### Phase 1: LSP Refactoring

1. Intercepts Neo-tree file operation events
2. Sends `workspace/willRenameFiles` request to all active LSP servers
3. Collects `WorkspaceEdit` responses from servers
4. Converts to internal edit format

**Advantages:**
- Semantically correct
- Language-aware
- No false positives
- Handles complex references (re-exports, type imports, etc.)

**Limitations:**
- Only works for LSP-managed files
- Requires LSP server support (not all servers implement `willRename`)

---

### Phase 2: Fallback Search

If LSP doesn't find all references, fallback search activates:

1. Builds search patterns from old path
2. Uses ripgrep (or native search) to find literal matches
3. Calculates confidence scores for each match
4. Filters by confidence threshold

**Advantages:**
- Works for any file type
- Finds non-semantic references (config files, documentation, etc.)
- No LSP dependency

**Limitations:**
- Can have false positives
- Less intelligent than LSP
- Requires manual review (via preview)

---

### Phase 3: Review & Apply

1. Combines LSP and fallback results
2. Shows unified preview with diff-style highlighting
3. User confirms or cancels
4. Applies all changes atomically
5. Saves modified buffers

---

## Supported LSP Servers

Servers with confirmed `workspace/willRenameFiles` support:

- **TypeScript/JavaScript**: `typescript-language-server`, `tsserver`
- **Lua**: `lua-language-server` (partial support)
- **Go**: `gopls`
- **Rust**: `rust-analyzer`
- **Python**: `pylsp`, `pyright` (limited)
- **C/C++**: `clangd`

Check your server's capabilities:

```lua
:lua =vim.lsp.get_active_clients()[1].server_capabilities.workspace.fileOperations
```

---

## Preview Window

The preview window shows:

- Total number of changes
- File path and line number for each change
- Diff-style view (old → new)
- Source of edit (LSP or fallback)
- Confidence level (fallback only)

---

### Keymaps (in preview)

- `<CR>` - Apply all changes
- `<Esc>` / `q` - Cancel
- `j` / `k` / `↓` / `↑` - Navigate

---

## Troubleshooting

### No Changes Detected

**Problem**: Plugin says "No references found"

**Solutions**:
1. Check if LSP server is running: `:LspInfo`
2. Verify server supports `willRename`: `:checkhealth neotree-fs-refactor`
3. Enable fallback search if disabled
4. Check `ignore_patterns` - file might be excluded

---

### LSP Timeout

**Problem**: "Request timeout" errors

**Solutions**:
1. Increase `timeout_ms` in config
2. Check LSP server logs: `:LspLog`
3. Try restarting LSP: `:LspRestart`

---

### False Positives in Fallback

**Problem**: Fallback finds incorrect matches

**Solutions**:
1. Increase `confidence_threshold` to `"high"`
2. Disable fallback entirely: `enable_fallback = false`
3. Add patterns to `ignore_patterns`
4. Review changes carefully in preview before applying

---

### Ripgrep Not Found

**Problem**: "ripgrep not found" warning

**Solutions**:
1. Install ripgrep: https://github.com/BurntSushi/ripgrep#installation
2. Or use native search: `fallback = { tool = "native" }`

---

## Performance Considerations

- **Lazy Loading**: Modules loaded on-demand
- **Efficient Search**: Ripgrep for large codebases
- **Debounced I/O**: Batched file writes
- **Buffer Reuse**: Minimizes buffer churn
- **Weak Tables**: Automatic cache cleanup

---

## Contributing

Contributions welcome! Please follow:

1. Code style from `Arch&Coding-Regeln.md`
2. Add tests for new features
3. Update documentation
4. Run `:checkhealth neotree-fs-refactor` before submitting

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Related Projects

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) - File explorer
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) - LSP configuration
- [refactoring.nvim](https://github.com/ThePrimeagen/refactoring.nvim) - Code refactoring

---

## Acknowledgments

Inspired by IDE refactoring tools and the need for seamless file management in Neovim.

---
