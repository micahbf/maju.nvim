# maju.nvim

A Magit-style interface for [Jujutsu (jj)](https://github.com/jj-vcs/jj) in Neovim.

Maju brings the power of Magit's interactive workflow to Jujutsu's change-centric model. It provides a status buffer with inline diffs, foldable hunks, and transient popup menus for common operations — all without leaving Neovim.

> **Status:** MVP / Early development. Core workflow is functional but expect rough edges.

## Requirements

- Neovim >= 0.11
- [Jujutsu](https://github.com/jj-vcs/jj) installed and on PATH
- A jj repository (colocated with git or native)

No external Neovim plugin dependencies. No plenary.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "micahbf/maju.nvim",
  cmd = "Maju",
  keys = {
    { "<leader>jj", "<cmd>Maju<cr>", desc = "Maju status" },
  },
  opts = {},
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "micahbf/maju.nvim",
  config = function()
    require("maju").setup()
  end,
}
```

## Usage

```
:Maju              Open status buffer (auto split/vsplit based on window width)
:Maju tab          Open in a new tab
:Maju split        Open in a horizontal split
:Maju floating     Open in a floating window
```

## Status Buffer

The status buffer shows:

- **Head** — current working copy change (change ID, author, timestamp, description)
- **Parent** — parent revision with bookmark info
- **Working copy changes** — files modified in `@`, expandable with inline diffs
- **Parent changes** — files modified in `@-`, expandable with inline diffs
- **Conflicts** — conflicted files (if any)
- **Recent changes** — log of recent revisions

### Keybindings

#### Navigation

| Key     | Action                              |
| ------- | ----------------------------------- |
| `<tab>` | Toggle fold (section / file / hunk) |
| `<cr>`  | Go to file at cursor position       |
| `{`     | Jump to previous section            |
| `}`     | Jump to next section                |

#### Hunk Operations (normal + visual mode)

| Key | Action                                                           |
| --- | ---------------------------------------------------------------- |
| `S` | Squash to parent — move selected files from `@` into `@-`        |
| `U` | Unsquash from parent — move selected files from `@-` back to `@` |
| `x` | Restore/discard — revert selected files to parent state          |

#### Popups

| Key | Action                                                           |
| --- | ---------------------------------------------------------------- |
| `c` | **Change** — new, new before, edit, describe, abandon, duplicate |
| `b` | **Bookmark** — create, set, move, delete, rename, track, untrack |
| `?` | **Help** — show all keybindings                                  |

#### Other

| Key | Action          |
| --- | --------------- |
| `g` | Refresh         |
| `q` | Close buffer    |
| `$` | Command history |
| `y` | Yank change ID  |

## Configuration

```lua
require("maju").setup({
  -- Buffer open style: "auto", "tab", "split", "vsplit", "floating", "replace"
  kind = "auto",

  -- Line numbers in maju buffers
  disable_line_numbers = true,
  disable_relative_line_numbers = true,

  -- Persistent popup switch/option state
  remember_settings = true,
  use_per_project_settings = true,
})
```

All options have sensible defaults. Calling `setup()` with no arguments is fine.

## How It Works

### jj vs git — Key Concepts

| git (magit/neogit)          | jj (maju)                                     |
| --------------------------- | --------------------------------------------- |
| Staging area / index        | No equivalent — use `jj squash` / `jj split`  |
| `git add` (stage)           | `jj squash` (move hunks from `@` into parent) |
| `git reset` (unstage)       | `jj squash --from @- --into @` (unsquash)     |
| `git checkout --` (discard) | `jj restore` (restore from parent)            |
| `git commit`                | `jj new` (create new empty change on top)     |
| `git commit --amend`        | Implicit — edits auto-amend `@`               |
| HEAD / branch               | `@` (working copy) / bookmarks                |
| commit SHA                  | change ID (e.g. `kpqxywon`)                   |
| branches                    | bookmarks                                     |

### Architecture

Maju is structured in layers:

- **Process** (`lib/process.lua`) — `vim.system()` wrapper for running jj commands
- **CLI** (`lib/jj/cli.lua`) — fluent command builder: `jj.diff.git_format.revision("@").call()`
- **Data** (`lib/jj/*.lua`) — repository state, diff parsing, status parsing, log parsing
- **UI** (`lib/ui/*.lua`) — declarative component tree rendered to buffer lines with highlights and folds
- **Buffer** (`lib/buffer.lua`) — buffer/window lifecycle, keymaps, fold management
- **Popup** (`lib/popup/*.lua`) — transient menus with switches, options, and actions

The UI component system and buffer abstraction are adapted from [neogit](https://github.com/NeogitOrg/neogit). The diff parser handles `jj diff --git` output, which uses standard unified diff format.

## Highlight Groups

All highlight groups use the `Maju` prefix and link to standard Neovim groups by default. Override them in your colorscheme or config:

```lua
vim.api.nvim_set_hl(0, "MajuChangeId", { fg = "#f9e2af", italic = true })
vim.api.nvim_set_hl(0, "MajuBookmark", { fg = "#a6e3a1", bold = true })
vim.api.nvim_set_hl(0, "MajuSectionHeader", { fg = "#89b4fa", bold = true })
```

Key groups: `MajuDiffAdd`, `MajuDiffDelete`, `MajuDiffContext`, `MajuHunkHeader`, `MajuSectionHeader`, `MajuChangeId`, `MajuBookmark`, `MajuChangeModified`, `MajuChangeAdded`, `MajuChangeDeleted`, `MajuPopupActionKey`, `MajuSubtleText`.

## License

MIT
