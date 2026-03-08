local jj = require("maju.lib.jj.cli")
local log = require("maju.lib.jj.log")
local status = require("maju.lib.jj.status")
local change = require("maju.lib.jj.change")
local diff = require("maju.lib.jj.diff")

local M = {}

M.state = {
  root = nil,
  working_copy = nil,      ---@type LogEntry|nil
  parents = {},             ---@type LogEntry[]
  parent_immutable = false, ---@type boolean
  changes = {},             ---@type FileChange[]
  parent_changes = {},      ---@type FileChange[]
  conflicts = {},           ---@type string[]
  recent = {},              ---@type LogEntry[]
}

---@param root string
function M.refresh(root)
  M.state.root = root
  jj._root = root

  -- Fetch working copy revision info
  M.state.working_copy = log.get_revision("@")

  -- Fetch all parents (supports merge commits)
  M.state.parents = log.get_revisions("parents(@)")

  -- Cache parent immutability
  M.state.parent_immutable = change.is_immutable("@-")

  -- Fetch file changes from jj status
  local st = status.get()
  M.state.changes = st.working_copy_changes
  M.state.conflicts = st.conflicts

  -- Fetch parent file changes
  M.state.parent_changes = status.get_parent_changes("@-")

  -- Fetch recent log
  M.state.recent = log.get_recent(10)

  -- Set up lazy diff loading on working copy changes
  for _, file in ipairs(M.state.changes) do
    diff.build_metatable(file, "@")
  end

  -- Set up lazy diff loading on parent changes
  for _, file in ipairs(M.state.parent_changes) do
    diff.build_metatable(file, "@-")
  end
end

---@param root string
---@param callback fun()
function M.refresh_async(root, callback)
  M.state.root = root
  jj._root = root

  -- 4 parallel streams: wc+parents+immutability, status, parent changes, recent log
  local pending = 4
  local results = {}

  local function on_done()
    pending = pending - 1
    if pending > 0 then
      return
    end

    -- Apply results to state
    M.state.working_copy = results.working_copy
    M.state.parents = results.parents or {}
    M.state.parent_immutable = results.parent_immutable or false
    M.state.changes = results.changes or {}
    M.state.conflicts = results.conflicts or {}
    M.state.parent_changes = results.parent_changes or {}
    M.state.recent = results.recent or {}

    -- Set up lazy diff loading on working copy changes
    for _, file in ipairs(M.state.changes) do
      diff.build_metatable(file, "@")
    end

    -- Set up lazy diff loading on parent changes
    for _, file in ipairs(M.state.parent_changes) do
      diff.build_metatable(file, "@-")
    end

    callback()
  end

  -- 1. Working copy -> parents -> immutability (chained)
  log.get_revision_async("@", function(wc)
    results.working_copy = wc
    log.get_revisions_async("parents(@)", function(parents)
      results.parents = parents
      results.parent_immutable = change.is_immutable("@-")
      on_done()
    end)
  end)

  -- 2. Status (working copy changes + conflicts)
  status.get_async(function(st)
    results.changes = st.working_copy_changes
    results.conflicts = st.conflicts
    on_done()
  end)

  -- 3. Parent changes
  status.get_parent_changes_async("@-", function(parent_changes)
    results.parent_changes = parent_changes
    on_done()
  end)

  -- 4. Recent log
  log.get_recent_async(10, function(recent)
    results.recent = recent
    on_done()
  end)
end

function M.reset()
  M.state = {
    root = nil,
    working_copy = nil,
    parents = {},
    parent_immutable = false,
    changes = {},
    parent_changes = {},
    conflicts = {},
    recent = {},
  }
end

return M
