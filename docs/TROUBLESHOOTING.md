# Troubleshooting

## Nothing happens when I rename a file in Neo-tree

- Run `:checkhealth neotree-fs-refactor` — confirms neo-tree.nvim is
  installed and the plugin is enabled.
- Check the file's extension is one of `file_types` in your config (default:
  `.lua`, `.py`, `.ts`/`.tsx`, `.js`/`.jsx`). Other filetypes have no pattern
  replacer and are silently skipped.
- Set `notify_on_refactor = true` (the default) and watch `:messages` — a
  "Found 0 files with potential references" message means the scan ran but
  found nothing, which is different from the scan not running at all.

## A reference wasn't updated

- The plugin only rewrites `require()`/`import` *statements*, not later uses
  of a name bound by one — e.g. after `import pkg.util.shared`, a later
  `pkg.util.shared.greet()` elsewhere in the same file is not rewritten. See
  [`docs/ROADMAP.md`](ROADMAP.md#known-limitations-to-close).
- For Python/TypeScript/JavaScript, renaming a *directory* only updates
  references to files renamed directly inside it, not a cascade to every
  file nested under it (Lua directory renames do cascade). Also tracked in
  the roadmap.
- Matching is pattern-based, not AST/treesitter — a `require()`/`import`
  split across multiple lines, or built from string concatenation, won't be
  recognized.

## It's slow on a large project

Check `:checkhealth neotree-fs-refactor` for whether ripgrep was found. If
it's missing, the plugin falls back to a pure-Lua directory walk that reads
every candidate-extension file — install ripgrep for a large speedup.

## Debugging

```lua
require("neotree-fs-refactor").setup({
  notify_on_refactor = true,  -- see per-rename summaries
})
```

Every notification the plugin emits is prefixed `[neotree-fs-refactor]`, so
`:messages` (or your `vim.notify` handler of choice, e.g. `nvim-notify`) will
show the full sequence of what it found and changed for a given rename.
