# Contributing to neotree-fs-refactor.nvim

Thanks for your interest in contributing.

## Getting started

- Neovim >= 0.10
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for running tests;
  `tests/run_tests.sh` installs it automatically if missing)
- ripgrep (optional — a pure-Lua fallback covers its absence)

```bash
git clone https://github.com/StefanBartl/neotree-fs-refactor.nvim
cd neotree-fs-refactor.nvim
tests/run_tests.sh
```

Point your local Neovim config at the clone for manual testing:

```lua
{
  dir = "~/path/to/neotree-fs-refactor.nvim",
  dependencies = { "nvim-neo-tree/neo-tree.nvim" },
  config = function()
    require("neotree-fs-refactor").setup()
  end,
}
```

## Architecture

See [`docs/PROJECT-STRUCTURE.md`](PROJECT-STRUCTURE.md) for the module
layout and data flow. In short:

```
init.lua
  └─> core/event_handlers.lua   (subscribes to Neo-tree's own events)
        └─> core/refactor.lua   (the actual reference rewriting)
              └─> utils/scanner.lua   (finds candidate files: rg or pure-Lua walk)
                    └─> utils/path.lua   (path <-> module-name conversions)
```

There is exactly one implementation of the rename-handling logic — if you're
adding a change, it goes in `core/refactor.lua` (or its helpers), not a
parallel path. A second, unreachable implementation (a JSON require-cache,
`ui/picker.lua`, `refactor/require_finder.lua`) existed here until 2026-07 and
was removed; don't reintroduce that pattern.

## Coding standards

- Type-annotate public functions (`---@param`, `---@return`); the config
  shape lives in `@types.lua` as the single source of truth.
- Validate at the boundary (Neo-tree event args, user config in `setup()`),
  not everywhere internally — trust your own already-validated data.
- No dead/parallel code paths for the same feature (see Architecture above).
- Prefer `vim.system(argv_table)` over `vim.fn.system(string)`/
  `vim.fn.systemlist(string)` for shelling out — it skips the shell (and any
  shell-specific quoting bugs) entirely.

## Testing

```bash
tests/run_tests.sh
```

Add coverage in `tests/path_util_spec.lua` for pure path/string logic, or
`tests/integration_spec.lua` for anything that goes through
`core.refactor.rename_references` end to end (write fixture files to a real
temp dir, rename on disk, assert the rewritten references — see the existing
tests for the pattern, including the negative-control style test guarding
against over-matching a similarly-named-but-different module).

## Pull requests

- Run `tests/run_tests.sh` and `:checkhealth neotree-fs-refactor` before
  submitting.
- Describe what changed and why; link an issue if there is one.
- No license/CLA to sign — see the repository's licensing status directly if
  you're unsure before depending on this in something else.
