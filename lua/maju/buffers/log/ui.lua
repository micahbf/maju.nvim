local Ui = require("maju.lib.ui")
local Component = require("maju.lib.ui.component")
local util = require("maju.lib.util")

local text = Ui.text
local col = Ui.col
local row = Ui.row

local M = {}

--- Determine the graph marker highlight based on graph prefix content
---@param prefix string
---@return string
local function graph_highlight(prefix)
  if prefix:find("@") then
    return "MajuGraphCurrent"
  elseif prefix:find("◆") then
    return "MajuGraphImmutable"
  else
    return "MajuGraphNormal"
  end
end

--- Build text components for an ID with a bold unique prefix and a dim suffix.
---@param id string
---@param prefix_len integer
---@param bold_hl string
---@param dim_hl string
---@return table[] List of text components
local function id_components(id, prefix_len, bold_hl, dim_hl)
  prefix_len = math.min(prefix_len, #id)
  local prefix = id:sub(1, prefix_len)
  local suffix = id:sub(prefix_len + 1)
  local parts = { text.highlight(bold_hl)(prefix) }
  if suffix ~= "" then
    table.insert(parts, text.highlight(dim_hl)(suffix))
  end
  return parts
end

---@param entry GraphLogEntry
---@return table Component
local LogEntry = Component.new(function(entry)
  local children = {}

  -- Graph prefix
  table.insert(children, text.highlight(graph_highlight(entry.graph_prefix))(entry.graph_prefix))

  -- Change ID with bold unique prefix
  local cid_parts = id_components(
    entry.change_id,
    entry.change_id_prefix_len or #entry.change_id,
    "MajuChangeIdBold",
    "MajuChangeId"
  )
  for _, c in ipairs(cid_parts) do
    table.insert(children, c)
  end

  table.insert(children, text(" "))

  -- Commit ID (short)
  local short_oid = entry.commit_id:sub(1, 7)
  local oid_parts = id_components(
    short_oid,
    math.min(entry.commit_id_prefix_len or #short_oid, 7),
    "MajuCommitIdBold",
    "MajuCommitId"
  )
  for _, c in ipairs(oid_parts) do
    table.insert(children, c)
  end

  table.insert(children, text(" "))

  -- Bookmarks
  if entry.bookmarks and #entry.bookmarks > 0 then
    for _, b in ipairs(entry.bookmarks) do
      table.insert(children, text.highlight("MajuBookmark")(b .. " "))
    end
  end

  -- Empty marker
  if entry.empty then
    table.insert(children, text.highlight("MajuSubtleText")("(empty) "))
  end

  -- Description
  local desc = entry.description or "(no description set)"
  if desc == "" then
    desc = "(no description set)"
  end
  table.insert(children, text(desc))

  -- Timestamp (right-aligned virtual text)
  table.insert(children, text.highlight("MajuTimestamp")(" " .. entry.email .. " " .. entry.timestamp))

  return row(children, {
    change_id = entry.change_id,
    yankable = entry.change_id,
  })
end)

---@param graph_text string
---@return table Component
local EdgeLine = Component.new(function(graph_text)
  return row {
    text.highlight("MajuGraphEdge")(graph_text),
  }
end)

---@param graph_lines GraphLine[]
---@param revset? string
---@return table[] Component list
function M.render(graph_lines, revset)
  local items = {}

  -- Header
  local header_text = "Log"
  if revset then
    header_text = header_text .. " (" .. revset .. ")"
  end
  table.insert(items, row {
    text.highlight("MajuSectionHeader")(header_text),
  })
  table.insert(items, row { text("") })

  -- Graph entries
  local entry_components = {}
  for _, gl in ipairs(graph_lines) do
    if gl.type == "commit" and gl.entry then
      table.insert(entry_components, LogEntry(gl.entry))
    elseif gl.type == "edge" and gl.graph_text then
      table.insert(entry_components, EdgeLine(gl.graph_text))
    end
  end

  if #entry_components > 0 then
    table.insert(items, col.tag("LogEntries")(
      entry_components,
      { section = "log" }
    ))
  end

  return items
end

return M
