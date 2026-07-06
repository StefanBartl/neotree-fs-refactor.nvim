```
┌──────────────────────────────────────────────────────────────────────────┐
│                      neotree-fs-refactor.nvim                            │
└──────────────────────────────────────────────────────────────────────────┘
```

![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-brightgreen?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-blue?logo=lua)
![Status](https://img.shields.io/badge/status-alpha-orange)

> **Pairs well with [filetree.nvim](https://github.com/StefanBartl/filetree.nvim)** — filetree.nvim covers the general file-tree UX (picker, marks, batch rename, and more) across any tree plugin; this plugin adds the one thing it doesn't do: keeping `require()`/`import` statements correct when you rename or move a file.

Automatic `require()`/`import` reference updates for Neo-tree file operations.
Rename or move a file/directory in Neo-tree, and every reference to it
elsewhere in your project — plus any open buffer — gets rewritten to match.

## Features

- **Automatic on rename/move**: subscribes to Neo-tree's own events, nothing
  to wire up in your Neo-tree config.
- **Lua, Python, TypeScript, JavaScript**: `require()`, `from`/`import`, and
  relative TS/JS imports (computed correctly per referencing file, not a
  single global guess).
- **Directory renames cascade**: renaming `testfs/rem` → `testfs/remolus`
  also updates `require("testfs.rem.da")` → `require("testfs.remolus.da")`
  (Lua only for now — see [Known limitations](#known-limitations)).
- **No hard external dependency**: uses ripgrep when it's on `$PATH` for a
  fast project scan, and falls back to a pure-Lua directory walk otherwise.
- **Delete warnings**: notifies you when a deleted file still has references
  elsewhere, instead of silently leaving them broken.

## Requirements

- Neovim >= 0.10 (uses `vim.system()`)
- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- ripgrep (optional — a pure-Lua fallback is used automatically without it)

## Installation

### lazy.nvim

```lua
{
  "StefanBartl/neotree-fs-refactor.nvim",
  dependencies = { "nvim-neo-tree/neo-tree.nvim" },
  event = "VeryLazy",
  config = function()
    require("neotree-fs-refactor").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "StefanBartl/neotree-fs-refactor.nvim",
  requires = { "nvim-neo-tree/neo-tree.nvim" },
  event = "VeryLazy",
  config = function()
    require("neotree-fs-refactor").setup()
  end,
}
```

## Configuration

`setup({})` accepts a `Neotree.FSRefactor.Config` table (see
[`@types.lua`](lua/neotree-fs-refactor/@types.lua)). Every field is optional;
shown here with its default:

```lua
require("neotree-fs-refactor").setup({
  enabled = true,
  auto_save = false,           -- save buffers after rewriting a reference in them
  notify_on_refactor = true,   -- show a summary notification per rename
  ignore_patterns = {
    "node_modules/**", ".git/**", "dist/**", "build/**", "*.min.js",
  },
  file_types = {                -- only filetypes with a pattern replacer
    lua = true,
    typescript = true,
    javascript = true,
    typescriptreact = true,
    javascriptreact = true,
    python = true,
  },
  max_file_size = 1024 * 1024, -- skip files larger than this (bytes)
  debounce_ms = 100,            -- debounce rapid rename/move/delete events
})
```

## Usage

Rename or move a file/directory in Neo-tree — that's it. The plugin:

1. Updates any open buffer referencing the old path.
2. Scans the project (ripgrep if available, otherwise a plain directory
   walk) for files referencing the old path.
3. Rewrites matching `require()`/`import` statements in those files.

Deleting a file instead prints a warning listing any file that still
references it, so you know what to go fix.

### Programmatic API

```lua
-- Manually trigger the same reference update Neo-tree triggers automatically
-- (useful for scripting, or wiring up a different file-tree plugin's rename event)
require("neotree-fs-refactor").refactor(old_path, new_path)

-- Same checks as :checkhealth neotree-fs-refactor
require("neotree-fs-refactor").check()
```

## Known limitations

- Only `require()`/`import` statements are rewritten — a later reference to
  the same module via a bound local name (e.g. Python's
  `pkg.util.shared.greet()` after `import pkg.util.shared`) is not.
- Directory-rename submodule cascading (see Features above) currently only
  applies to Lua.
- No AST/treesitter parsing — matching is pattern-based, so requires/imports
  split across multiple lines or built from string concatenation aren't
  recognized.

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for what's planned to address these.

## Testing

```bash
tests/run_tests.sh
```

Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (installed
automatically by the script if missing). Covers path utilities and an
end-to-end integration suite (Lua/Python/TS/JS rename scenarios, including a
negative control for similarly-named-but-unrelated modules).

## Health check

```vim
:checkhealth neotree-fs-refactor
```

## Documentation

- [`:help neotree-fs-refactor`](doc/neotree-fs-refactor.txt)
- [`docs/BINDINGS.md`](docs/BINDINGS.md) — keymaps/commands/events (there are
  none to bind; this plugin is purely event-driven)
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — planned features and known gaps
- [`docs/PROJECT-STRUCTURE.md`](docs/PROJECT-STRUCTURE.md) — module layout and data flow
