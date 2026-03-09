# CLAUDE.md — maju.nvim

## What This Is

maju.nvim is a Magit-style interface for the Jujutsu (jj) VCS in Neovim. It provides a status buffer with inline diffs, foldable hunks, and transient popup menus. Target: Neovim 0.11+, zero external Lua dependencies.

## Project Structure

```
plugin/maju.lua                       Entry point — :Maju command
lua/maju/
  init.lua                            setup(), open(), find_root()
  config.lua                          Configuration defaults

  lib/
    process.lua                       vim.system() wrapper
    buffer.lua                        Buffer/window abstraction (ported from neogit)
    util.lua                          Table/string utilities
    notification.lua                  vim.notify wrapper
    input.lua                         User input prompts
    state.lua                         Persistent state via mpack
    color.lua                         Color class (hex/hsv/shade manipulation)
    hl.lua                            Highlight groups (palette-based, adapts to colorscheme)

    jj/
      cli.lua                         Fluent jj command builder (metatable-based)
      repository.lua                  Central state singleton + refresh
      status.lua                      Parse jj status output
      diff.lua                        Parse jj diff --git (unified diff)
      log.lua                         Parse jj log (NUL-separated template, graph log)
      change.lua                      new, edit, describe, abandon, duplicate
      squash.lua                      squash, unsquash, restore (whole-file)
      bookmark.lua                    Bookmark CRUD
      describe.lua                    Multi-line description read/write
      revset.lua                      Completion helpers

    ui/
      component.lua                   Component factory (text/row/col)
      renderer.lua                    Tree → buffer renderer
      init.lua                        Ui class: selection, cursor, folds

    popup/
      builder.lua                     Fluent popup builder API
      init.lua                        Popup display + interaction
      ui.lua                          Popup rendering

  buffers/
    common.lua                        Shared: Diff, DiffHunks, Hunk, HunkLine, EmptyLine
    status/
      init.lua                        Status buffer lifecycle (singleton)
      ui.lua                          Status buffer component tree
      actions.lua                     Keybinding handlers
    log/
      init.lua                        Log view buffer (graph, revset filter)
      ui.lua                          Log view component tree
      actions.lua                     Log view actions (edit, rebase, open change)
    change/
      init.lua                        Change detail view (single change)
      ui.lua                          Change view component tree
      actions.lua                     Change view actions
    describe/
      init.lua                        Describe editor (multi-line, :w saves)
    oplog/
      init.lua                        Operation log buffer
      ui.lua                          Operation log component tree
      actions.lua                     Operation log actions (restore)

  popups/
    change/init.lua + actions.lua     new, edit, describe, abandon, duplicate
    bookmark/init.lua + actions.lua   create, set, move, delete, rename, track, untrack
    help/init.lua                     All keybindings display

scripts/
  maju-diff-tool                      External diff editor for jj squash/split --tool
```

## Key Patterns

### CLI Builder
Commands are built fluently: `jj.diff.git_format.revision("@").call()`. The builder uses metatables — flags are bare properties, options take a value. `call()` runs synchronously, `call_async(cb)` runs async. Always adds `--no-pager --color never`. The root is set via `jj._root`.

### Lazy Diff Loading
File items in repository state have metatables. Accessing `file.diff` triggers `jj diff --git -r <rev> -- <file>` on first access via `__index`. Use `rawget(file, "diff")` to check without triggering.

### Component Tree
UI is declarative: `col { row { text("hello") } }`. Components have options like `foldable`, `folded`, `section`, `item`, `change_id`, `yankable`, `on_open`. The renderer walks the tree and produces buffer lines, highlights, extmarks, and folds.

### Fold State Persistence
Before re-render, `get_fold_state()` captures which nodes are folded (keyed by section/filename/hunk hash). After render, `set_fold_state()` restores it. Cursor location is similarly captured and restored.

### Status Buffer Singleton
`require("maju.buffers.status").instance` holds the current instance. `M.open(root, kind)` creates or focuses. `instance:refresh()` re-fetches data and redraws. `instance:close()` saves fold/cursor state.

### Popup System
Popups use a fluent builder: `:name()`, `:group_heading()`, `:action(key, desc, callback)`, `:switch()`, `:option()`, `:build()`. The popup opens as a bottom-anchored floating window that auto-closes on `q`, `<esc>`, or `WinLeave`.

### Color Palette
`hl.lua` builds a color palette at setup time by reading the current colorscheme's Normal bg/fg and deriving shaded variants via `color.lua`'s Color class. This means highlights adapt to any colorscheme (dark or light). Users can override base colors via `config.highlight = { red = "#...", green = "#...", ... }`. The palette provides `bg_*` (tinted backgrounds), `line_*` (diff line backgrounds), and `md_*` (medium-shade) variants for each base color.

## Naming Conventions

- jj uses "change ID" not "commit SHA" — the codebase uses `change_id` throughout (not `oid`)
- jj uses "bookmarks" not "branches"
- `@` = working copy, `@-` = parent
- Highlight groups: `Maju*` prefix (not `Neogit*`)
- Namespaces/augroups: `maju-*` / `Maju-*` prefix

## Testing

No automated tests yet. Manual testing in a jj repository:
1. `:Maju` opens status buffer
2. `<tab>` expands file diffs (lazy loaded)
3. `S` on a working copy file squashes to parent
4. `U` on a parent file unsquashes back
5. `c` opens change popup, `b` opens bookmark popup
6. `g` refreshes, fold state persists

## Dependencies

- Neovim >= 0.11 (for `vim.system()`)
- jj CLI on PATH
- No plenary, no external Lua dependencies
- `jq` needed only if using `scripts/maju-diff-tool` for partial hunk squash

## Code Origins

The UI component system, renderer, Ui class, and buffer abstraction are ported from [neogit](https://github.com/NeogitOrg/neogit) with plenary removed and git concepts mapped to jj equivalents. The diff parser reuses neogit's unified diff parser unchanged (jj's `--git` output is identical format).
