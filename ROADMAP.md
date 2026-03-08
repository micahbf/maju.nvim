# Roadmap

## Current State: MVP Complete

The MVP delivers a functional daily-driver workflow: status buffer with inline diffs, fold persistence, whole-file squash/unsquash/restore, change and bookmark popups, and help.

---

## Wave 1: Hardening & Polish

Priority fixes to make the MVP solid for daily use.

### Partial Hunk Operations
- [x] Hunk-level squash: select a single hunk with cursor on it, press `S` — squash only that hunk via `jj squash --tool`
- [x] Visual-line partial squash: select specific `+`/`-` lines within a hunk, press `S` — squash only those lines
- [x] Same for unsquash (`U`) and restore (`x`) at hunk and line granularity
- [x] Wire up `scripts/maju-diff-tool` manifest generation from `item_hunks()` selection data
- [x] Implement line-level hunk selection in the diff tool (currently only full-file)

### Direct Working Copy Manipulation (for Restore)
- [x] For `x` (restore/discard): read parent content via `jj file show -r @- <file>`, apply reverse of selected hunks directly to disk
- [x] This avoids the `--tool` overhead for simple discard operations

### Error Handling & Edge Cases
- [x] Handle immutable revisions — check `is_immutable()` before squash/edit/abandon and show clear error
- [x] Handle merge commits (multiple parents) — currently assumes single parent
- [x] Handle empty working copy gracefully
- [x] Handle missing jj binary with clear error message
- [x] Handle renamed/copied files in diff parsing

### Async Refresh
- [x] Make `repository.refresh()` async — currently blocks UI during data fetch
- [x] Show loading indicator during refresh
- [x] Debounce rapid refreshes

---

## Wave 2: More Popups & Operations

### Rebase Popup (`r`)
- [ ] `d` — Rebase onto destination (`jj rebase -r @ -d <rev>`)
- [ ] `A` — Rebase after revision (`jj rebase -r @ -A <rev>`)
- [ ] `B` — Rebase before revision (`jj rebase -r @ -B <rev>`)
- [ ] `=r` option for specifying which revision to rebase

### Push Popup (`P`)
- [ ] `p` — Push (`jj git push`)
- [ ] `P` — Push all bookmarks (`jj git push --all`)
- [ ] `--all`, `--deleted` switches
- [ ] `--remote` option

### Fetch Popup (`f`)
- [ ] `f` — Fetch (`jj git fetch`)
- [ ] `F` — Fetch all remotes (`jj git fetch --all-remotes`)
- [ ] `--remote` option

### Undo Popup (`X`)
- [ ] `u` — Undo (`jj op undo`)
- [ ] `r` — Redo (`jj op undo` of the undo)
- [ ] `l` — Open operation log view

### Squash Popup (`s`)
- [ ] `s` — Squash to parent (with switches)
- [ ] `S` — Squash into specific revision
- [ ] `m` — Move changes to specific revision
- [ ] `-i` interactive switch

### Split Popup (`p`)
- [ ] `s` — Split interactively (`jj split -i`)
- [ ] `S` — Split at file level (select files to keep in first half)

### Diff Popup (`d`)
- [ ] `d` — View diff in diffview.nvim or vimdiff
- [ ] `s` — Show stat
- [ ] Options for controlling diff display

### Resolve Popup
- [ ] `r` — Resolve conflicts (`jj resolve`)
- [ ] `--tool` option for choosing merge tool

### Supporting Modules
- [ ] `lib/jj/remote.lua` — push/fetch operations
- [ ] `lib/jj/operation.lua` — undo, redo, op log parsing
- [ ] `lib/jj/split.lua` — split operations
- [ ] `lib/jj/conflict.lua` — conflict detection and info
- [ ] `lib/jj/describe.lua` — multi-line description editing

---

## Wave 3: Additional Buffers

### Log View Buffer
- [ ] Full log browser with graph visualization
- [ ] Interactive operations: edit, rebase, bookmark from log entries
- [ ] Customizable revset filter
- [ ] Keyboard navigation between changes

### Change View Buffer
- [ ] Single change detail view (all diffs, full description, metadata)
- [ ] Open from status buffer recent entries or log view

### Describe Editor Buffer
- [ ] Dedicated buffer for editing change descriptions (like neogit's commit editor)
- [ ] Multi-line editing with proper save/cancel
- [ ] Template support

### Operation Log Buffer
- [ ] View `jj op log` output
- [ ] Restore to any operation point
- [ ] Visual undo history

---

## Wave 4: Integration & Automation

### File System Watcher
- [ ] Watch `.jj/` directory for changes via `vim.uv` fs events
- [ ] Auto-refresh status buffer when jj state changes (e.g. after external `jj` commands)
- [ ] Debounce to avoid excessive refreshes

### Fuzzy Finder Integration
- [ ] `lib/finder.lua` — abstraction over telescope.nvim / fzf-lua / snacks.picker
- [ ] Bookmark picker for bookmark operations
- [ ] Change ID picker for revision inputs
- [ ] File picker for file-scoped operations

### Revset Autocomplete
- [ ] Completion in all revision input prompts
- [ ] Cache `jj log` results for change ID completion
- [ ] Cache `jj bookmark list` for bookmark name completion
- [ ] Live validation via `jj log -r <partial>`

### diffview.nvim Integration
- [ ] Open file diffs in diffview.nvim when available
- [ ] Side-by-side diff for any revision

### User-Configurable Keymaps
- [ ] Allow full keymap customization via `config.mappings`
- [ ] Per-buffer mapping overrides
- [ ] Document all default mappings

---

## Wave 5: Advanced Features

### Workspace Support
- [ ] Handle jj workspaces (multiple working copies)
- [ ] Switch between workspaces

### Evolog Integration
- [ ] View evolution log for a change
- [ ] Visualize change history (rewrites, squashes, etc.)

### Obslog Integration
- [ ] View obsolete predecessors of a change
- [ ] Restore from previous versions

### Colocated Git Awareness
- [ ] Detect colocated git+jj repos
- [ ] Show git-specific info where relevant (remote branches, etc.)

### Performance
- [ ] Lazy-load modules (only load popup modules when opened)
- [ ] Benchmark and optimize refresh cycle for large repos
- [ ] Incremental diff updates (only re-fetch changed files)
