local jj = require("maju.lib.jj.cli")
local bookmark = require("maju.lib.jj.bookmark")

local M = {}

---@class ChangeIdEntry
---@field id string
---@field desc string

---@return ChangeIdEntry[]
function M.all_change_ids()
  local result = jj.log.no_graph
    .template('change_id.short(8) ++ "\t" ++ description.first_line() ++ "\n"')
    .revisions("all()")
    .call({ ignore_error = true })

  if result.code ~= 0 then
    return {}
  end

  local entries = {}
  for _, line in ipairs(result.stdout) do
    if line ~= "" then
      local id, desc = line:match("^([^\t]+)\t(.*)$")
      if id then
        table.insert(entries, { id = id, desc = desc or "" })
      end
    end
  end
  return entries
end

---@return string[]
function M.all_bookmarks()
  return bookmark.get_all_names()
end

---@param revset string
---@return boolean
function M.validate(revset)
  local result = jj.log.no_graph.revisions(revset).template("").limit("1").call({ ignore_error = true })
  return result.code == 0
end

return M
