# Bindings

neotree-fs-refactor.nvim has no keymaps and no user commands. It works
entirely by subscribing to Neo-tree's own file-operation events — there is
nothing to bind, remap, or wire up with which-key.

## Keymaps

None.

## User commands

None. Everything happens automatically on Neo-tree rename/move/delete. For a
manual/programmatic trigger (e.g. from a script, or a different file-tree
plugin's rename event), use the Lua API instead:

```lua
require("neotree-fs-refactor").refactor(old_path, new_path)
```

## Neo-tree event subscriptions

Registered by [`core/event_handlers.lua`](../lua/neotree-fs-refactor/core/event_handlers.lua)
inside `setup()` — nothing to add to your Neo-tree config.

| Neo-tree event | Handler                    |
|-----------------|----------------------------|
| `FILE_RENAMED`   | `core.refactor.rename_references` |
| `FILE_MOVED`     | `core.refactor.move_references`   |
| `FILE_DELETED`   | `core.refactor.delete_references` |

Each is debounced (`debounce_ms`, default 100ms) to collapse rapid repeated
events from the same operation.
