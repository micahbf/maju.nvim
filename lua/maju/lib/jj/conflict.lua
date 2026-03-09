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

---@param opts? {revision?: string, tool?: string}
---@return string[] cmd_args Command arguments for terminal execution
function M.build_cmd(opts)
  opts = opts or {}
  local cmd = { "jj", "--no-pager", "--color", "never", "resolve" }
  if opts.revision then
    table.insert(cmd, "-r")
    table.insert(cmd, opts.revision)
  end
  if opts.tool then
    table.insert(cmd, "--tool")
    table.insert(cmd, opts.tool)
  end
  return cmd
end

---@param opts? {revision?: string}
---@return {success: boolean, error: string|nil, files: string[]}
function M.list(opts)
  opts = opts or {}
  local cmd = jj.resolve.list
  if opts.revision then
    cmd = cmd.revision(opts.revision)
  end
  local result = cmd.call({ ignore_error = true })
  if result.code == 0 then
    return { success = true, files = result.stdout }
  end
  return { success = false, error = table.concat(result.stderr, "\n"), files = {} }
end

return M
