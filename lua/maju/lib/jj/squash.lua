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

---@param opts? {revision?: string, from?: string, into?: string, files?: string[], interactive?: boolean, tool?: string}
---@return {success: boolean, error: string|nil}
function M.squash(opts)
  opts = opts or {}
  local cmd = jj.squash
  if opts.revision then
    cmd = cmd.revision(opts.revision)
  end
  if opts.from then
    cmd = cmd.from(opts.from)
  end
  if opts.into then
    cmd = cmd.into(opts.into)
  end
  if opts.interactive then
    cmd = cmd.interactive
  end
  if opts.tool then
    cmd = cmd.tool(opts.tool)
  end
  if opts.files and #opts.files > 0 then
    cmd = cmd.files(unpack(opts.files))
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param files string[]
---@return {success: boolean, error: string|nil}
function M.squash_files(files)
  return M.squash({ files = files })
end

---@param opts? {interactive?: boolean}
---@return {success: boolean, error: string|nil}
function M.unsquash(opts)
  opts = opts or {}
  local cmd = jj.squash.from("@-").into("@")
  if opts.interactive then
    cmd = cmd.interactive
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param files string[]
---@return {success: boolean, error: string|nil}
function M.unsquash_files(files)
  return M.squash({ from = "@-", into = "@", files = files })
end

---@param opts? {from?: string, to?: string, revision?: string, files?: string[]}
---@return {success: boolean, error: string|nil}
function M.restore(opts)
  opts = opts or {}
  local cmd = jj.restore
  if opts.from then
    cmd = cmd.from(opts.from)
  end
  if opts.to then
    cmd = cmd.to(opts.to)
  end
  if opts.revision then
    cmd = cmd.revision(opts.revision)
  end
  if opts.files and #opts.files > 0 then
    cmd = cmd.files(unpack(opts.files))
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param files string[]
---@return {success: boolean, error: string|nil}
function M.restore_files(files)
  return M.restore({ files = files })
end

return M
