local jj = require("maju.lib.jj.cli")

local M = {}

---@class FileChange
---@field mode string
---@field name string

local MODE_PATTERNS = {
  ["M "] = "M",
  ["A "] = "A",
  ["D "] = "D",
  ["R "] = "R",
  ["C "] = "C",
}

---@param lines string[]
---@return FileChange[]
function M.parse_changes(lines)
  local changes = {}
  for _, line in ipairs(lines) do
    local prefix = line:sub(1, 2)
    local mode = MODE_PATTERNS[prefix]
    if mode then
      local name = line:sub(3)
      table.insert(changes, { mode = mode, name = name })
    end
  end
  return changes
end

---@param lines string[]
---@return string[]
function M.parse_conflicts(lines)
  local conflicts = {}
  local in_conflicts = false
  for _, line in ipairs(lines) do
    if line:match("^Conflicting changes") or line:match("^There are unresolved conflicts") then
      in_conflicts = true
    elseif in_conflicts then
      local name = line:match("^%s+(.+)$")
      if name then
        table.insert(conflicts, name)
      elseif line == "" or not line:match("^%s") then
        in_conflicts = false
      end
    end
  end
  return conflicts
end

---@return {working_copy_changes: FileChange[], conflicts: string[]}
function M.get()
  local result = jj.status.call({ ignore_error = true })
  if result.code ~= 0 then
    return { working_copy_changes = {}, conflicts = {} }
  end

  return {
    working_copy_changes = M.parse_changes(result.stdout),
    conflicts = M.parse_conflicts(result.stdout),
  }
end

---@param callback fun(result: {working_copy_changes: FileChange[], conflicts: string[]})
function M.get_async(callback)
  jj.status.call_async(function(result)
    if result.code ~= 0 then
      callback({ working_copy_changes = {}, conflicts = {} })
    else
      callback({
        working_copy_changes = M.parse_changes(result.stdout),
        conflicts = M.parse_conflicts(result.stdout),
      })
    end
  end)
end

---@param revision string
---@return FileChange[]
function M.get_parent_changes(revision)
  local result = jj.diff.summary.revision(revision).call({ ignore_error = true })
  if result.code ~= 0 then
    return {}
  end
  return M.parse_changes(result.stdout)
end

---@param revision string
---@param callback fun(changes: FileChange[])
function M.get_parent_changes_async(revision, callback)
  jj.diff.summary.revision(revision).call_async(function(result)
    if result.code ~= 0 then
      callback({})
    else
      callback(M.parse_changes(result.stdout))
    end
  end)
end

return M
