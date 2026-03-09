local jj = require("maju.lib.jj.cli")

local M = {}

---@param revision string
---@return string
function M.get_description(revision)
  local result = jj.log.no_graph.revisions(revision).template("description").call({ ignore_error = true })
  if result.code ~= 0 then
    return ""
  end
  return table.concat(result.stdout, "\n")
end

---@param revision string
---@param callback fun(desc: string)
function M.get_description_async(revision, callback)
  jj.log.no_graph.revisions(revision).template("description").call_async(function(result)
    if result.code ~= 0 then
      callback("")
    else
      callback(table.concat(result.stdout, "\n"))
    end
  end)
end

---@param revision string
---@param message string
---@return {success: boolean, error: string|nil}
function M.set_description(revision, message)
  local result = jj.describe.revision(revision).message(message).call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param revision string
---@return string[]
function M.get_diff_summary(revision)
  local result = jj.diff.stat.revision(revision).call({ ignore_error = true })
  if result.code ~= 0 then
    return {}
  end
  return result.stdout
end

return M
