local Ui = require("maju.lib.ui")
local Component = require("maju.lib.ui.component")
local common = require("maju.buffers.common")
local util = require("maju.lib.util")

local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

local EmptyLine = common.EmptyLine

local M = {}

--- Build text components for an ID with a bold unique prefix and a dim suffix.
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

---@param label string
---@param value_components table[]
---@return table Component
local function info_row(label, value_components)
  local children = {
    text.highlight("MajuSectionHeader")(util.pad_right(label, 14)),
  }
  for _, c in ipairs(value_components) do
    table.insert(children, c)
  end
  return row(children)
end

---@param file table {mode, name}
---@param change_id string
---@return table Component
local FileItem = Component.new(function(file, change_id)
  local mode_hl = ({
    M = "MajuChangeModified",
    A = "MajuChangeAdded",
    D = "MajuChangeDeleted",
    R = "MajuChangeRenamed",
    C = "MajuChangeRenamed",
  })[file.mode] or "MajuChangeModified"

  local children = {
    text.highlight(mode_hl)(file.mode .. " "),
    text(file.name),
  }

  -- If the file has a loaded diff, show it inline
  local diff_component = nil
  if rawget(file, "diff") and file.diff and file.diff.hunks and #file.diff.hunks > 0 then
    diff_component = common.DiffHunks(file.diff)
  end

  return col.tag("Item")({
    row(children),
    diff_component,
  }, {
    foldable = true,
    folded = true,
    filename = file.name,
    item = file,
    on_open = function(this, ui_inst)
      -- Trigger lazy diff loading when fold is opened
      if not rawget(file, "diff") then
        local _ = file.diff -- triggers metatable __index
        if file.diff then
          -- Re-render with diff data
          local change_buf = require("maju.buffers.change")
          if change_buf.instance then
            ui_inst:render(unpack(M.render(change_buf.instance)))
          end
        end
      end
    end,
  })
end)

---@param instance ChangeBuffer
---@return table[] Component list
function M.render(instance)
  local items = {}
  local entry = instance.entry

  if not entry then
    table.insert(items, row { text.highlight("MajuChangeDeleted")("Change not found: " .. instance.change_id) })
    return items
  end

  -- Header: Change ID
  local cid_parts = id_components(
    entry.change_id,
    entry.change_id_prefix_len or #entry.change_id,
    "MajuChangeIdBold",
    "MajuChangeId"
  )
  table.insert(items, info_row("Change ID", cid_parts))

  -- Header: Commit ID
  local oid_parts = id_components(
    entry.commit_id,
    entry.commit_id_prefix_len or #entry.commit_id,
    "MajuCommitIdBold",
    "MajuCommitId"
  )
  table.insert(items, info_row("Commit ID", oid_parts))

  -- Author
  local author_text = entry.author_name or entry.email
  if entry.author_name and entry.email and entry.author_name ~= entry.email then
    author_text = entry.author_name .. " <" .. entry.email .. ">"
  end
  table.insert(items, info_row("Author", { text(author_text) }))

  -- Timestamp
  table.insert(items, info_row("Date", { text.highlight("MajuTimestamp")(entry.timestamp) }))

  -- Bookmarks
  if entry.bookmarks and #entry.bookmarks > 0 then
    local bookmark_parts = {}
    for _, b in ipairs(entry.bookmarks) do
      table.insert(bookmark_parts, text.highlight("MajuBookmark")(b .. " "))
    end
    table.insert(items, info_row("Bookmarks", bookmark_parts))
  end

  -- Flags
  local flags = {}
  if entry.empty then
    table.insert(flags, text.highlight("MajuSubtleText")("empty "))
  end
  if entry.conflict then
    table.insert(flags, text.highlight("MajuChangeDeleted")("conflict "))
  end
  if entry.immutable then
    table.insert(flags, text.highlight("MajuSubtleText")("immutable "))
  end
  if #flags > 0 then
    table.insert(items, info_row("Flags", flags))
  end

  table.insert(items, EmptyLine())

  -- Description section
  local desc = instance.description
  if desc == "" then
    desc = "(no description set)"
  end
  local desc_lines = {}
  for line in (desc .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(desc_lines, row { text(line) })
  end
  table.insert(items, col.tag("Description")(
    vim.list_extend(
      { row { text.highlight("MajuSectionHeader")("Description") } },
      desc_lines
    ),
    { foldable = true, folded = false, section = "description" }
  ))

  table.insert(items, EmptyLine())

  -- Changes section
  if #instance.changes > 0 then
    table.insert(items, col.tag("Changes")({
      row {
        text.highlight("MajuSectionHeader")(
          string.format("Changes (%d)", #instance.changes)
        ),
      },
      col(map(instance.changes, function(file)
        return FileItem(file, instance.change_id)
      end)),
    }, {
      foldable = true,
      folded = false,
      section = "changes",
    }))
  else
    table.insert(items, row { text.highlight("MajuSubtleText")("No changes") })
  end

  return items
end

return M
