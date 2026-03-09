# Roadmap

## Current State: Wave 3 Complete

Waves 1–3 are complete: status buffer with inline diffs, partial hunk operations, all popups (rebase, push, fetch, squash, split, undo, diff, resolve), log view with graph, change detail view, describe editor, and operation log buffer.

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
- [x] `d` — Rebase onto destination (`jj rebase -r @ -d <rev>`)
- [x] `A` — Rebase after revision (`jj rebase -r @ -A <rev>`)
- [x] `B` — Rebase before revision (`jj rebase -r @ -B <rev>`)
- [x] `=r` option for specifying which revision to rebase

### Push Popup (`P`)
- [x] `p` — Push (`jj git push`)
- [x] `P` — Push all bookmarks (`jj git push --all`)
- [x] `--all`, `--deleted` switches
- [x] `--remote` option

### Fetch Popup (`f`)
- [x] `f` — Fetch (`jj git fetch`)
- [x] `F` — Fetch all remotes (`jj git fetch --all-remotes`)
- [x] `--remote` option

### Undo Popup (`X`)
- [x] `u` — Undo (`jj op undo`)
- [x] `r` — Redo (`jj op undo` of the undo)
- [x] `l` — Open operation log view

### Squash Popup (`s`)
- [x] `s` — Squash to parent (with switches)
- [x] `S` — Squash into specific revision
- [x] `m` — Move changes to specific revision
- [x] `-i` interactive switch

### Split Popup (`p`)
- [x] `s` — Split interactively (`jj split -i`)
- [x] `S` — Split at file level (select files to keep in first half)

### Diff Popup (`d`)
- [x] `d` — View diff in floating buffer with diff filetype
- [x] `s` — Show stat
- [x] `=r` option for revision

### Resolve Popup
- [x] `r` — Resolve conflicts (`jj resolve`)
- [x] `--tool` option for choosing merge tool

### Supporting Modules
- [x] `lib/jj/remote.lua` — push/fetch operations
- [x] `lib/jj/operation.lua` — undo, redo, op log parsing
- [x] `lib/jj/rebase.lua` — rebase operations
- [x] `lib/jj/split.lua` — split operations
- [x] `lib/jj/conflict.lua` — conflict detection and resolution
- [x] `lib/terminal.lua` — terminal runner for interactive commands
- [x] `lib/jj/describe.lua` — multi-line description editing

---

## Wave 3: Additional Buffers

### Log View Buffer
- [x] Full log browser with graph visualization
- [x] Interactive operations: edit, rebase, bookmark from log entries
- [x] Customizable revset filter
- [x] Keyboard navigation between changes

### Change View Buffer
- [x] Single change detail view (all diffs, full description, metadata)
- [x] Open from status buffer recent entries or log view

### Describe Editor Buffer
- [x] Dedicated buffer for editing change descriptions (like neogit's commit editor)
- [x] Multi-line editing with proper save/cancel
- [ ] Template support

### Operation Log Buffer
- [x] View `jj op log` output
- [x] Restore to any operation point
- [x] Visual undo history

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
