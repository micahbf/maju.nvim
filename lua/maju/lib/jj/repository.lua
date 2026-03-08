local jj = require("maju.lib.jj.cli")
local log = require("maju.lib.jj.log")
local status = require("maju.lib.jj.status")
local diff = require("maju.lib.jj.diff")

local M = {}

M.state = {
  root = nil,
  working_copy = nil, ---@type LogEntry|nil
  parents = {},       ---@type LogEntry[]
  changes = {},       ---@type FileChange[]
  parent_changes = {}, ---@type FileChange[]
  conflicts = {},     ---@type string[]
  recent = {},        ---@type LogEntry[]
}

---@param root string
function M.refresh(root)
  M.state.root = root
  jj._root = root

  -- Fetch working copy revision info
  M.state.working_copy = log.get_revision("@")

  -- Fetch parent revision info
  local parent = log.get_revision("@-")
  M.state.parents = parent and { parent } or {}

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

function M.reset()
  M.state = {
    root = nil,
    working_copy = nil,
    parents = {},
    changes = {},
    parent_changes = {},
    conflicts = {},
    recent = {},
  }
end

return M
