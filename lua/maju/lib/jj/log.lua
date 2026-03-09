local jj = require("maju.lib.jj.cli")

local M = {}

-- Use ASCII Unit Separator (0x1f) as field delimiter.
-- NUL (\x00) gets truncated by C strings in vim.system() argv — never use it.
-- We use jj's own \x1f escape in the template so the command arg is clean ASCII.
local SEP = "\x1f" -- actual byte, for splitting output
local TEMPLATE = table.concat({
  "change_id.shortest()",
  "change_id.short(8)",
  "commit_id.shortest()",
  "commit_id.short(12)",
  "author.email()",
  "author.timestamp().ago()",
  'if(empty, "true", "false")',
  'if(conflict, "true", "false")',
  'local_bookmarks.map(|b| b.name()).join(",")',
  "description.first_line()",
}, ' ++ "\\x1f" ++ ') .. ' ++ "\\n"'

-- Graph template: uses \x1e (Record Separator) as start-of-data sentinel.
-- When jj log runs WITH graph, it prefixes each line with graph characters.
-- Lines containing \x1e have commit data; lines without are pure graph edges.
-- No trailing \n since graph mode adds its own newlines.
local RS = "\x1e" -- Record Separator byte, for detecting data lines
local GRAPH_TEMPLATE = '"\\x1e" ++ ' .. table.concat({
  "change_id.shortest()",
  "change_id.short(8)",
  "commit_id.shortest()",
  "commit_id.short(12)",
  "author.email()",
  "author.timestamp().ago()",
  'if(empty, "true", "false")',
  'if(conflict, "true", "false")',
  'if(immutable, "true", "false")',
  'local_bookmarks.map(|b| b.name()).join(",")',
  "description.first_line()",
}, ' ++ "\\x1f" ++ ')

-- Detail template: includes author name and immutable flag for change view.
local DETAIL_TEMPLATE = table.concat({
  "change_id.shortest()",
  "change_id.short(8)",
  "commit_id.shortest()",
  "commit_id.short(12)",
  "author.name()",
  "author.email()",
  "author.timestamp().ago()",
  'if(empty, "true", "false")',
  'if(conflict, "true", "false")',
  'if(immutable, "true", "false")',
  'local_bookmarks.map(|b| b.name()).join(",")',
  "description.first_line()",
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

---@class DetailEntry : LogEntry
---@field author_name string
---@field immutable boolean

---@param line string
---@return DetailEntry|nil
function M.parse_detail_entry(line)
  if not line or line == "" then
    return nil
  end

  local parts = vim.split(line, SEP, { plain = true })
  if #parts < 12 then
    return nil
  end

  return {
    change_id = parts[2],
    change_id_prefix_len = #parts[1],
    commit_id = parts[4],
    commit_id_prefix_len = #parts[3],
    author_name = parts[5],
    email = parts[6],
    timestamp = parts[7],
    empty = parts[8] == "true",
    conflict = parts[9] == "true",
    immutable = parts[10] == "true",
    bookmarks = parts[11] ~= "" and vim.split(parts[11], ",", { plain = true }) or {},
    description = parts[12],
  }
end

---@class GraphLogEntry : LogEntry
---@field immutable boolean
---@field graph_prefix string

---@param line string
---@return GraphLogEntry|nil
local function parse_graph_data(line)
  local rs_pos = line:find(RS, 1, true)
  if not rs_pos then
    return nil
  end

  local graph_prefix = line:sub(1, rs_pos - 1)
  local data = line:sub(rs_pos + 1)
  local parts = vim.split(data, SEP, { plain = true })
  if #parts < 11 then
    return nil
  end

  return {
    graph_prefix = graph_prefix,
    change_id = parts[2],
    change_id_prefix_len = #parts[1],
    commit_id = parts[4],
    commit_id_prefix_len = #parts[3],
    email = parts[5],
    timestamp = parts[6],
    empty = parts[7] == "true",
    conflict = parts[8] == "true",
    immutable = parts[9] == "true",
    bookmarks = parts[10] ~= "" and vim.split(parts[10], ",", { plain = true }) or {},
    description = parts[11],
  }
end

---@class GraphLine
---@field type "commit"|"edge"
---@field entry GraphLogEntry|nil  Only for type="commit"
---@field graph_text string|nil    Only for type="edge"

---@param revset? string
---@param opts? {limit?: number}
---@return GraphLine[]
function M.get_graph_log(revset, opts)
  opts = opts or {}
  local cmd = jj.log.template(GRAPH_TEMPLATE)
  if revset then
    cmd = cmd.revisions(revset)
  end
  if opts.limit then
    cmd = cmd.limit(tostring(opts.limit))
  end
  local result = cmd.call({ ignore_error = true })
  if result.code ~= 0 then
    return {}
  end

  return M.parse_graph_lines(result.stdout)
end

---@param lines string[]
---@return GraphLine[]
function M.parse_graph_lines(lines)
  local graph_lines = {}
  for _, line in ipairs(lines) do
    local entry = parse_graph_data(line)
    if entry then
      table.insert(graph_lines, { type = "commit", entry = entry })
    else
      table.insert(graph_lines, { type = "edge", graph_text = line })
    end
  end
  return graph_lines
end

---@param revset? string
---@param opts? {limit?: number}
---@param callback fun(lines: GraphLine[])
function M.get_graph_log_async(revset, opts, callback)
  opts = opts or {}
  local cmd = jj.log.template(GRAPH_TEMPLATE)
  if revset then
    cmd = cmd.revisions(revset)
  end
  if opts.limit then
    cmd = cmd.limit(tostring(opts.limit))
  end
  cmd.call_async(function(result)
    if result.code ~= 0 then
      callback({})
      return
    end
    callback(M.parse_graph_lines(result.stdout))
  end)
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
---@return DetailEntry|nil
function M.get_detail(revset)
  local result = jj.log.no_graph.revisions(revset).template(DETAIL_TEMPLATE).call({ ignore_error = true })
  if result.code ~= 0 or #result.stdout == 0 then
    return nil
  end
  return M.parse_detail_entry(result.stdout[1])
end

---@param revset string
---@param callback fun(entry: DetailEntry|nil)
function M.get_detail_async(revset, callback)
  jj.log.no_graph.revisions(revset).template(DETAIL_TEMPLATE).call_async(function(result)
    if result.code ~= 0 or #result.stdout == 0 then
      callback(nil)
    else
      callback(M.parse_detail_entry(result.stdout[1]))
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
