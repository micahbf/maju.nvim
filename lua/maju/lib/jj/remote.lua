local jj = require("maju.lib.jj.cli")

local M = {}

---@param result ProcessResult
---@return {success: boolean, error: string|nil, output: string|nil}
local function wrap_result(result)
  if result.code == 0 then
    local output = #result.stdout > 0 and table.concat(result.stdout, "\n") or nil
    return { success = true, output = output }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param opts? {all_remotes?: boolean, remote?: string}
---@return {success: boolean, error: string|nil, output: string|nil}
function M.fetch(opts)
  opts = opts or {}
  local cmd = jj.git.fetch
  if opts.all_remotes then
    cmd = cmd.all_remotes
  end
  if opts.remote then
    cmd = cmd.remote(opts.remote)
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param opts? {all?: boolean, deleted?: boolean, remote?: string, bookmark?: string, change?: string, dry_run?: boolean}
---@return {success: boolean, error: string|nil, output: string|nil}
function M.push(opts)
  opts = opts or {}
  local cmd = jj.git.push
  if opts.all then
    cmd = cmd.all
  end
  if opts.deleted then
    cmd = cmd.deleted
  end
  if opts.dry_run then
    cmd = cmd.dry_run
  end
  if opts.remote then
    cmd = cmd.remote(opts.remote)
  end
  if opts.bookmark then
    cmd = cmd.bookmark(opts.bookmark)
  end
  if opts.change then
    cmd = cmd.change(opts.change)
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

return M
