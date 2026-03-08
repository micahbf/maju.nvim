local jj = require("maju.lib.jj.cli")

local M = {}

---@param result ProcessResult
---@return {success: boolean, error: string|nil}
local function wrap_result(result)
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param opts? {revision?: string, message?: string, insert_before?: boolean, insert_after?: boolean}
---@return {success: boolean, error: string|nil}
function M.new(opts)
  opts = opts or {}
  local cmd = jj.new
  if opts.message then
    cmd = cmd.message(opts.message)
  end
  if opts.insert_before then
    cmd = cmd.insert_before
  end
  if opts.insert_after then
    cmd = cmd.insert_after
  end
  if opts.revision then
    cmd = cmd.args(opts.revision)
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param revision string
---@return {success: boolean, error: string|nil}
function M.edit(revision)
  return wrap_result(jj.edit.revision(revision).call({ ignore_error = true }))
end

---@param revision string
---@param message string
---@return {success: boolean, error: string|nil}
function M.describe(revision, message)
  return wrap_result(jj.describe.revision(revision).message(message).call({ ignore_error = true }))
end

---@param revision string
---@return {success: boolean, error: string|nil}
function M.abandon(revision)
  return wrap_result(jj.abandon.revision(revision).call({ ignore_error = true }))
end

---@param revisions string[]
---@return {success: boolean, error: string|nil}
function M.duplicate(revisions)
  return wrap_result(jj.duplicate.arg_list(revisions).call({ ignore_error = true }))
end

---@param revision string
---@return boolean
function M.is_immutable(revision)
  local result = jj.log.no_graph.revisions(revision).template('if(immutable, "true", "false")').call({ ignore_error = true })
  if result.code ~= 0 or #result.stdout == 0 then
    return false
  end
  return result.stdout[1] == "true"
end

return M
