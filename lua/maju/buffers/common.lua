local Ui = require("maju.lib.ui")
local Component = require("maju.lib.ui.component")
local util = require("maju.lib.util")

local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map
local filter = util.filter
local intersperse = util.intersperse

local M = {}

M.EmptyLine = Component.new(function()
  return col { row { text("") } }
end)

M.Diff = Component.new(function(diff)
  return col.tag("Diff")({
    text(string.format("%s %s", diff.kind, diff.file), { line_hl = "MajuDiffHeader" }),
    M.DiffHunks(diff),
  }, { foldable = true, folded = false, context = true })
end)

M.DiffHunks = Component.new(function(diff)
  local hunk_props = vim
    .iter(diff.hunks)
    :map(function(hunk)
      hunk.content = vim.iter(diff.lines):slice(hunk.diff_from + 1, hunk.diff_to):totable()
      return {
        header = diff.lines[hunk.diff_from],
        content = hunk.content,
        hunk = hunk,
        folded = hunk._folded,
      }
    end)
    :totable()

  return col.tag("DiffContent") {
    col.tag("DiffInfo")(map(diff.info, text)),
    col.tag("HunkList")(map(hunk_props, M.Hunk)),
  }
end)

local HunkLine = Component.new(function(line)
  local line_hl
  local first_char = string.sub(line, 1, 1)

  if first_char == "+" then
    line_hl = "MajuDiffAdd"
  elseif first_char == "-" then
    line_hl = "MajuDiffDelete"
  else
    line_hl = "MajuDiffContext"
  end

  return text(line, { line_hl = line_hl })
end)

M.Hunk = Component.new(function(props)
  return col.tag("Hunk")({
    text.line_hl("MajuHunkHeader")(props.header),
    col.tag("HunkContent")(map(props.content, HunkLine)),
  }, { foldable = true, folded = props.folded or false, context = true, hunk = props.hunk })
end)

M.List = Component.new(function(props)
  local children = filter(props.items, function(x)
    return type(x) == "table"
  end)

  if props.separator then
    children = intersperse(children, text(props.separator))
  end

  local container = col
  if props.horizontal then
    container = row
  end

  return container.tag("List")(children)
end)

M.Grid = Component.new(function(props)
  props = vim.tbl_extend("force", {
    gap = 0,
    columns = true,
    items = {},
  }, props)

  -- Transpose if columns mode
  if props.columns then
    local new_items = {}
    local row_count = 0
    for i = 1, #props.items do
      local l = #props.items[i]
      if l > row_count then
        row_count = l
      end
    end
    for _ = 1, row_count do
      table.insert(new_items, {})
    end
    for i = 1, #props.items do
      for j = 1, row_count do
        local x = props.items[i][j] or text("")
        table.insert(new_items[j], x)
      end
    end
    props.items = new_items
  end

  local rendered = {}
  local column_widths = {}

  for i = 1, #props.items do
    local children = {}
    local r = props.items[i]

    for j = 1, #r do
      local item = r[j]
      local c = props.render_item(item)

      if c.tag ~= "text" and c.tag ~= "row" then
        error("Grid component only supports text and row components for now")
      end

      local c_width = c:get_width()
      children[j] = c

      if c_width > (column_widths[j] or 0) then
        column_widths[j] = c_width
      end
    end

    rendered[i] = row(children)
  end

  for i = 1, #rendered do
    local r = rendered[i]
    for j = 1, #r.children do
      local item = r.children[j]
      local gap_str = ""
      local column_width = column_widths[j] or 0

      if j ~= 1 then
        gap_str = string.rep(" ", props.gap)
      end

      if item.tag == "text" then
        item.value = gap_str .. string.format("%" .. column_width .. "s", item.value)
      elseif item.tag == "row" then
        table.insert(item.children, 1, text(gap_str))
        local width = item:get_width()
        local remaining_width = column_width - width + props.gap
        table.insert(item.children, text(string.rep(" ", remaining_width)))
      end
    end
  end

  return col(rendered)
end)

return M
