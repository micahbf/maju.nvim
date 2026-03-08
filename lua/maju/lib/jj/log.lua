local jj = require("maju.lib.jj.cli")

local M = {}

-- Use ASCII Unit Separator (0x1f) as field delimiter.
-- NUL (\x00) gets truncated by C strings in vim.system() argv — never use it.
-- We use jj's own \x1f escape in the template so the command arg is clean ASCII.
local SEP = "\x1f" -- actual byte, for splitting output
local TEMPLATE = table.concat({
  'change_id.shortest()',
  'change_id.short(8)',
  'commit_id.shortest()',
  'commit_id.short(12)',
  'author.email()',
  'author.timestamp().ago()',
  'if(empty, "true", "false")',
  'if(conflict, "true", "false")',
  'local_bookmarks.map(|b| b.name()).join(",")',
  'description.first_line()',
}, ' ++ "\\x1f" ++ ') .. ' ++ "\\n"'

---@class LogEntry
---@field change_id string
---@field change_id_prefix_len integer Length of the shortest unique prefix
---@field commit_id string
---@field commit_id_prefix_len integer Length of the shortest unique prefix
---@field email string
---@field timestamp string
---@field empty boolean
---@field conflict boolean
---@field bookmarks string[]
---@field description string

---@param line string
---@return LogEntry|nil
function M.parse_entry(line)
  if not line or line == "" then
    return nil
  end

  local parts = vim.split(line, SEP, { plain = true })
  if #parts < 10 then
    return nil
  end

  return {
    change_id = parts[2],
    change_id_prefix_len = #parts[1],
    commit_id = parts[4],
    commit_id_prefix_len = #parts[3],
    email = parts[5],
    timestamp = parts[6],
    empty = parts[7] == "true",
    conflict = parts[8] == "true",
    bookmarks = parts[9] ~= "" and vim.split(parts[9], ",", { plain = true }) or {},
    description = parts[10],
  }
end

---@param revset string
---@return LogEntry|nil
function M.get_revision(revset)
  local result = jj.log.no_graph.revisions(revset).template(TEMPLATE).call({ ignore_error = true })
  if result.code ~= 0 or #result.stdout == 0 then
    return nil
  end
  return M.parse_entry(result.stdout[1])
end

---@param revset string
---@param callback fun(entry: LogEntry|nil)
function M.get_revision_async(revset, callback)
  jj.log.no_graph.revisions(revset).template(TEMPLATE).call_async(function(result)
    if result.code ~= 0 or #result.stdout == 0 then
      callback(nil)
    else
      callback(M.parse_entry(result.stdout[1]))
    end
  end)
end

---@param revset string
---@return LogEntry[]
function M.get_revisions(revset)
  local result = jj.log.no_graph.revisions(revset).template(TEMPLATE).call({ ignore_error = true })
  if result.code ~= 0 then
    return {}
  end

  local entries = {}
  for _, line in ipairs(result.stdout) do
    local entry = M.parse_entry(line)
    if entry then
      table.insert(entries, entry)
    end
  end
  return entries
end

---@param revset string
---@param callback fun(entries: LogEntry[])
function M.get_revisions_async(revset, callback)
  jj.log.no_graph.revisions(revset).template(TEMPLATE).call_async(function(result)
    if result.code ~= 0 then
      callback({})
      return
    end

    local entries = {}
    for _, line in ipairs(result.stdout) do
      local entry = M.parse_entry(line)
      if entry then
        table.insert(entries, entry)
      end
    end
    callback(entries)
  end)
end

---@param limit? integer
---@return LogEntry[]
function M.get_recent(limit)
  limit = limit or 10
  local revset = string.format("ancestors(@-, %d)", limit)
  return M.get_revisions(revset)
end

---@param limit integer|nil
---@param callback fun(entries: LogEntry[])
function M.get_recent_async(limit, callback)
  limit = limit or 10
  local revset = string.format("ancestors(@-, %d)", limit)
  M.get_revisions_async(revset, callback)
end

return M
