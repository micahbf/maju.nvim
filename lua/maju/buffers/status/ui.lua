local Ui = require("maju.lib.ui")
local Component = require("maju.lib.ui.component")
local common = require("maju.buffers.common")
local util = require("maju.lib.util")

local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

local EmptyLine = common.EmptyLine
local Diff = common.Diff
local List = common.List

local M = {}

--- Build text components for an ID with a bold unique prefix and a dim suffix.
---@param id string The full ID string (e.g. 8-char change_id)
---@param prefix_len integer Length of the shortest unique prefix
---@param bold_hl string Highlight group for the bold prefix
---@param dim_hl string Highlight group for the dim suffix
---@param trailing? string Optional trailing text (e.g. " ")
---@return table[] List of text components
local function id_components(id, prefix_len, bold_hl, dim_hl, trailing)
  trailing = trailing or ""
  prefix_len = math.min(prefix_len, #id)
  local prefix = id:sub(1, prefix_len)
  local suffix = id:sub(prefix_len + 1) .. trailing
  local parts = { text.highlight(bold_hl)(prefix) }
  if suffix ~= "" then
    table.insert(parts, text.highlight(dim_hl)(suffix))
  end
  return parts
end

---@param entry table LogEntry
---@param label string e.g. "Head" or "Parent"
---@param revspec string e.g. "@" or "@-"
---@return table Component
local Header = Component.new(function(entry, label, revspec)
  local children = {
    text.highlight("MajuSectionHeader")(util.pad_right(label, 18)),
  }

  -- Change ID with bold unique prefix
  local cid_parts = id_components(
    entry.change_id,
    entry.change_id_prefix_len or #entry.change_id,
    "MajuChangeIdBold",
    "MajuChangeId",
    " "
  )
  for _, c in ipairs(cid_parts) do
    table.insert(children, c)
  end

  -- Commit ID with bold unique prefix
  local oid_parts = id_components(
    entry.commit_id,
    entry.commit_id_prefix_len or #entry.commit_id,
    "MajuCommitIdBold",
    "MajuCommitId",
    " "
  )
  for _, c in ipairs(oid_parts) do
    table.insert(children, c)
  end

  if entry.empty then
    table.insert(children, text.highlight("MajuSubtleText")("(empty) "))
  end

  if entry.bookmarks and #entry.bookmarks > 0 then
    for _, b in ipairs(entry.bookmarks) do
      table.insert(children, text.highlight("MajuBookmark")(b .. " "))
    end
  end

  local desc = entry.description or "(no description set)"
  if desc == "" then
    desc = "(no description set)"
  end

  table.insert(children, text("| " .. desc))

  return row(children, {
    change_id = entry.change_id,
    yankable = entry.change_id,
  })
end)

---@param file table {mode, name}
---@return table Component
local FileItem = Component.new(function(file, section_name)
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
    section = nil,
    item = file,
    on_open = function(this, ui)
      -- Trigger lazy diff loading when fold is opened
      if not rawget(file, "diff") then
        local _ = file.diff -- triggers metatable __index
        if file.diff then
          -- Re-render with diff data
          ui:render(unpack(M.render(require("maju.lib.jj.repository").state)))
        end
      end
    end,
  })
end)

---@param entry table LogEntry
---@return table Component
local RecentEntry = Component.new(function(entry)
  local bookmark_text = ""
  if entry.bookmarks and #entry.bookmarks > 0 then
    bookmark_text = "  " .. table.concat(entry.bookmarks, ", ")
  end

  local desc = entry.description or "(empty)"
  if desc == "" then
    desc = "(empty)"
  end

  local empty_marker = entry.empty and " (empty)" or ""

  local children = {
    text.highlight("MajuSubtleText")("  "),
  }

  -- Change ID with bold unique prefix
  local cid_parts = id_components(
    entry.change_id,
    entry.change_id_prefix_len or #entry.change_id,
    "MajuChangeIdBold",
    "MajuChangeId",
    ""
  )
  for _, c in ipairs(cid_parts) do
    table.insert(children, c)
  end

  -- Commit ID (short SHA)
  local short_oid = entry.commit_id:sub(1, 7)
  local oid_parts = id_components(
    short_oid,
    math.min(entry.commit_id_prefix_len or #short_oid, 7),
    "MajuCommitIdBold",
    "MajuCommitId",
    ""
  )
  table.insert(children, text(" "))
  for _, c in ipairs(oid_parts) do
    table.insert(children, c)
  end

  table.insert(children, text("  "))
  table.insert(children, text(desc))
  table.insert(children, text.highlight("MajuBookmark")(bookmark_text))
  table.insert(children, text.highlight("MajuSubtleText")(empty_marker))

  return row(children, {
    change_id = entry.change_id,
    yankable = entry.change_id,
  })
end)

---@param state table Repository state
---@return table[] Component list
function M.render(state)
  local items = {}

  -- Header section: working copy + parent info (like jj status)
  if state.working_copy then
    table.insert(items, Header(state.working_copy, "Working copy (@):", "@"))
  end

  if state.parents and #state.parents > 0 then
    if #state.parents == 1 then
      table.insert(items, Header(state.parents[1], "Parent (@-):", "@-"))
    else
      for i, parent in ipairs(state.parents) do
        local label = string.format("Parent %d:", i)
        table.insert(items, Header(parent, label, "@-"))
      end
    end
  end

  table.insert(items, EmptyLine())

  -- Working copy changes section
  if #state.changes > 0 then
    table.insert(
      items,
      col.tag("WcChanges")({
        row {
          text.highlight("MajuSectionHeader")(
            string.format("Working copy changes (%d)", #state.changes)
          ),
        },
        col(map(state.changes, function(file)
          return FileItem(file, "working_copy")
        end)),
      }, {
        foldable = true,
        folded = false,
        section = "working_copy",
      })
    )
    table.insert(items, EmptyLine())
  else
    table.insert(items, row { text.highlight("MajuSubtleText")("No working copy changes") })
    table.insert(items, EmptyLine())
  end

  -- Parent changes section
  if #state.parent_changes > 0 then
    table.insert(
      items,
      col.tag("ParentChanges")({
        row {
          text.highlight("MajuSectionHeader")(
            string.format("Parent changes (%d)", #state.parent_changes)
          ),
        },
        col(map(state.parent_changes, function(file)
          return FileItem(file, "parent")
        end)),
      }, {
        foldable = true,
        folded = true,
        section = "parent",
      })
    )
    table.insert(items, EmptyLine())
  end

  -- Conflicts section
  if #state.conflicts > 0 then
    table.insert(
      items,
      col.tag("Conflicts")({
        row {
          text.highlight("MajuChangeDeleted")(
            string.format("Conflicts (%d)", #state.conflicts)
          ),
        },
        col(map(state.conflicts, function(name)
          return row {
            text.highlight("MajuChangeDeleted")("  " .. name),
          }
        end)),
      }, {
        foldable = true,
        folded = false,
        section = "conflicts",
      })
    )
    table.insert(items, EmptyLine())
  end

  -- Recent changes section
  if #state.recent > 0 then
    table.insert(
      items,
      col.tag("Recent")({
        row {
          text.highlight("MajuSectionHeader")("Recent changes"),
        },
        col(map(state.recent, RecentEntry)),
      }, {
        foldable = true,
        folded = false,
        section = "recent",
      })
    )
  end

  return items
end

return M
