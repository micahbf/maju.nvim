local jj = require("maju.lib.jj.cli")

local M = {}

local SEP = "\x1f"
local OP_TEMPLATE = table.concat({
  "self.id().short(16)",
  "self.description()",
  "self.time().start().ago()",
  'if(self.current_operation, "true", "false")',
}, ' ++ "\\x1f" ++ ') .. ' ++ "\\n"'

---@param result ProcessResult
---@return {success: boolean, error: string|nil}
local function wrap_result(result)
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@return {success: boolean, error: string|nil}
function M.undo()
  return wrap_result(jj.op.undo.call({ ignore_error = true }))
end

---@return {success: boolean, error: string|nil}
function M.redo()
  -- In jj, "redo" is undoing the undo
  return wrap_result(jj.op.undo.call({ ignore_error = true }))
end

---@param opts? {limit?: number}
---@return {success: boolean, error: string|nil, lines: string[]}
function M.op_log(opts)
  opts = opts or {}
  local cmd = jj.op.log
  if opts.limit then
    cmd = cmd.limit(tostring(opts.limit))
  end
  local result = cmd.call({ ignore_error = true })
  if result.code == 0 then
    return { success = true, lines = result.stdout }
  end
  return { success = false, error = table.concat(result.stderr, "\n"), lines = {} }
end

---@class OpLogEntry
---@field op_id string
---@field description string
---@field timestamp string
---@field current boolean

---@param line string
---@return OpLogEntry|nil
function M.parse_op_entry(line)
  if not line or line == "" then
    return nil
  end

  local parts = vim.split(line, SEP, { plain = true })
  if #parts < 4 then
    return nil
  end

  return {
    op_id = parts[1],
    description = parts[2],
    timestamp = parts[3],
    current = parts[4] == "true",
  }
end

---@param opts? {limit?: number}
---@return OpLogEntry[]
function M.get_op_log_structured(opts)
  opts = opts or {}
  local cmd = jj.op.log.no_graph.template(OP_TEMPLATE)
  if opts.limit then
    cmd = cmd.limit(tostring(opts.limit))
  end
  local result = cmd.call({ ignore_error = true })
  if result.code ~= 0 then
    return {}
  end

  local entries = {}
  for _, line in ipairs(result.stdout) do
    local entry = M.parse_op_entry(line)
    if entry then
      table.insert(entries, entry)
    end
  end
  return entries
end

---@param opts? {limit?: number}
---@param callback fun(entries: OpLogEntry[])
function M.get_op_log_structured_async(opts, callback)
  opts = opts or {}
  local cmd = jj.op.log.no_graph.template(OP_TEMPLATE)
  if opts.limit then
    cmd = cmd.limit(tostring(opts.limit))
  end
  cmd.call_async(function(result)
    if result.code ~= 0 then
      callback({})
      return
    end

    local entries = {}
    for _, line in ipairs(result.stdout) do
      local entry = M.parse_op_entry(line)
      if entry then
        table.insert(entries, entry)
      end
    end
    callback(entries)
  end)
end

---@param op_id string
---@return {success: boolean, error: string|nil}
function M.restore(op_id)
  return wrap_result(jj.op.restore.args(op_id).call({ ignore_error = true }))
end

return M
