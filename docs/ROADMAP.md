# Roadmap

Planned features, commands, keymaps, and autocmds for neotree-fs-refactor.nvim.
Nothing here is committed to a timeline — it's a backlog, ranked roughly by
how much it actually addresses a real limitation vs. being a nice-to-have.

## Known limitations to close

- **Submodule cascading for Python/TS/JS directory renames.** Lua directory
  renames already cascade to nested `require()` references (`testfs.rem` →
  `testfs.remolus` also updates `testfs.rem.da`); Python packages and TS/JS
  folders don't yet — see [`core/refactor.lua`](../lua/neotree-fs-refactor/core/refactor.lua).
- **Attribute-style references after `import`.** `import pkg.util.shared`
  followed later by `pkg.util.shared.greet()` only updates the `import` line,
  not the later attribute-access usage.
- **Multi-line / concatenated requires.** Matching is pattern-based (no
  treesitter/AST), so a `require()` split across lines or built from string
  concatenation isn't recognized.

## Potential new features

- **Dry-run mode**: preview the file/line diff before writing (the plugin
  used to have this via a `require_finder`/`file_updater`/picker pipeline
  that was removed as dead, broken code during the 2026-07 cleanup — worth
  re-adding as a real feature on top of the current, working scanner instead
  of restoring the old implementation as-is).
- **Undo integration**: batch all rewritten files into a single undo step
  usable via native Neovim undo, not just per-file undo history.
- **User command** for a manual one-off refactor without a Neo-tree rename
  (`require("neotree-fs-refactor").refactor(old, new)` already exists as a
  Lua API — a thin `:NeotreeFsRefactor {old} {new}` wrapper would cover
  users who'd rather not drop into Lua).
- **Go/Rust/C/C++ support**: these were listed in `file_types` before the
  2026-07 cleanup but never had a pattern replacer implemented — either
  build real support or don't advertise them.

## No keymaps/autocmds planned

The plugin has no UI surface (see [`docs/BINDINGS.md`](BINDINGS.md)) — it's
purely event-driven off Neo-tree, and there's no roadmap item that would
change that.
