local Ui = require("maju.lib.ui")
local Component = require("maju.lib.ui.component")
local util = require("maju.lib.util")

local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

local M = {}

---@param entry OpLogEntry
---@return table Component
local OpEntry = Component.new(function(entry)
  local children = {}

  -- Current marker
  if entry.current then
    table.insert(children, text.highlight("MajuOpCurrent")("@ "))
  else
    table.insert(children, text("  "))
  end

  -- Operation ID
  table.insert(children, text.highlight("MajuOpId")(entry.op_id .. " "))

  -- Timestamp
  table.insert(children, text.highlight("MajuTimestamp")(entry.timestamp .. " "))

  -- Description
  table.insert(children, text(entry.description))

  return row(children, {
    yankable = entry.op_id,
    change_id = entry.op_id,
  })
end)

---@param entries OpLogEntry[]
---@return table[] Component list
function M.render(entries)
  local items = {}

  table.insert(items, row {
    text.highlight("MajuSectionHeader")("Operation Log"),
  })
  table.insert(items, row { text("") })

  if #entries > 0 then
    table.insert(items, col.tag("OpEntries")(
      map(entries, OpEntry),
      { section = "operations" }
    ))
  end

  return items
end

return M
