# Features worth porting to filetree.nvim

`filetree.nvim` (`E:\repos\filetree.nvim`) is the cross-platform,
filetree-manager-agnostic (Neo-tree, nvim-tree, netrw, oil, mini.files)
successor this plugin's ideas eventually move into. This is the running list
of what from neotree-fs-refactor.nvim is worth taking over, where it landed
(or should land), and anything else worth knowing.

## Already ported

| Feature | Origin (this repo) | Landed in filetree.nvim | Notes |
|---|---|---|---|
| require()/import reference update on rename | `core/refactor.lua` | `features/fileops/smart_rename/init.lua` (`update_references_fallback`, `build_line_replacer`) | Ported as a **fallback** that only runs when no LSP client applied a `workspace/willRenameFiles` edit (always true for Lua — lua_ls doesn't implement it) — not a wholesale copy. The per-file relative-import bug (see below) was actually caught and fixed *there* first, then fixed here too when it turned up again during this repo's own cleanup. |

## New gap found during this repo's 2026-07 cleanup — not yet ported

| Feature | Origin (this repo) | Where it fits | Notes |
|---|---|---|---|
| Directory-rename submodule cascading | `core/refactor.lua` `get_patterns_for_filetype` (lua branch) | `features/fileops/smart_rename/init.lua` `build_line_replacer` | Renaming a Lua directory (`testfs.rem` → `testfs.remolus`) must also update `require("testfs.rem.da")` → `require("testfs.remolus.da")`, not just exact `require("testfs.rem")` matches. filetree.nvim's `smart_rename` fallback currently only does the exact-match case — same gap this repo had until this session's testing caught it (see `tests/integration_spec.lua`'s "Lua directory rename" test). Worth the same fix: match `old_module` optionally followed by `.<suffix>`, requiring a literal `.` before the suffix so a same-prefix-different-module case (`rem` vs `rem_other`) never false-positives. |

## Nice-to-have, not urgent

| Feature | Origin (this repo) | Where it'd fit | Notes |
|---|---|---|---|
| Delete-time reference warning | `core/refactor.lua` `delete_references` | `features/fileops/trash/init.lua` | "N file(s) still reference the file you just deleted" — cheap (~10 lines) reusing the same scan already built for rename. Flagged as a candidate in the original filetree.nvim analysis; still not built. |
| Configurable scan ignore patterns | `config/DEFAULTS.lua` `ignore_patterns` | `features/fileops/smart_rename/init.lua` `find_candidate_files` | filetree's fallback hardcodes `.git`/`node_modules` as skip globs; this repo's `ignore_patterns` config (glob list) is user-configurable. Minor, would need to actually use them in the rg glob args instead of the fixed pair. |

## Latent bug of the same shape, found while fixing this repo — worth checking

`filetree.nvim`'s `features/search/grep_in_dir/init.lua` (`via_builtin`, the
rg branch) builds its ripgrep command as a hand-joined string
(`table.concat(args, " ")`) passed to `vim.fn.systemlist`, with **no
escaping at all** for the rg branch (the grep-fallback branch does use
`vim.fn.shellescape`, just not the rg branch). This repo had the exact same
class of bug in `utils/scanner.lua` — it broke outright as soon as `&shell`
was something other than a Windows-default shell (e.g. Git Bash configured
as `&shell` on Windows), because the hand-built quoted string got mangled by
the OS process-creation layer. The fix here was `vim.system(argv)` (no
shell, no quoting needed) instead of `vim.fn.system(string)`. Not something
this session touched in filetree.nvim, but worth the same fix there.
