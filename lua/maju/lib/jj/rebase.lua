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

---@param opts {revision?: string, source?: string, destination?: string, insert_after?: string, insert_before?: string}
---@return {success: boolean, error: string|nil}
function M.rebase(opts)
  opts = opts or {}
  local cmd = jj.rebase
  if opts.revision then
    cmd = cmd.revision(opts.revision)
  end
  if opts.source then
    cmd = cmd.source(opts.source)
  end
  if opts.destination then
    cmd = cmd.destination(opts.destination)
  end
  if opts.insert_after then
    cmd = cmd.insert_after(opts.insert_after)
  end
  if opts.insert_before then
    cmd = cmd.insert_before(opts.insert_before)
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

return M
