local M = {}

local common = require("maju.buffers.common")
local Ui = require("maju.lib.ui")
local util = require("maju.lib.util")

local EmptyLine = common.EmptyLine
local List = common.List
local Grid = common.Grid
local col = Ui.col
local row = Ui.row
local text = Ui.text
local Component = Ui.Component

local filter_map = util.filter_map
local map = util.map

local function get_highlight_for_switch(switch)
  if switch.enabled then
    return "MajuPopupSwitchEnabled"
  end
  return "MajuPopupSwitchDisabled"
end

local function get_highlight_for_option(option)
  if option.value ~= nil and option.value ~= "" then
    return "MajuPopupOptionEnabled"
  end
  return "MajuPopupOptionDisabled"
end

local Switch = Component.new(function(switch)
  local value = row
    .id(switch.id)
    .highlight(get_highlight_for_switch(switch)) { text(switch.cli_prefix), text(switch.cli) }

  return row.tag("Switch").value(switch)({
    row.highlight("MajuPopupSwitchKey") {
      text(switch.key_prefix),
      text(switch.key),
    },
    text(" "),
    text(switch.description),
    text(" ("),
    value,
    text(")"),
  }, { interactive = true })
end)

local Option = Component.new(function(option)
  return row.tag("Option").value(option)({
    row.highlight("MajuPopupOptionKey") {
      text(option.key_prefix),
      text(option.key),
    },
    text(" "),
    text(option.description),
    text(" ("),
    row.id(option.id).highlight(get_highlight_for_option(option)) {
      text(option.cli_prefix),
      text(option.cli),
      text(option.separator),
      text(option.value or ""),
    },
    text(")"),
  }, { interactive = true })
end)

local Section = Component.new(function(title, items)
  return col {
    text.highlight("MajuPopupSectionTitle")(title),
    col(items),
  }
end)

local function render_action(action)
  local items = {}

  if action.keys == nil then
    -- Action group heading
  elseif action.keys == "" then
    table.insert(items, text(""))
  elseif #action.keys == 0 then
    table.insert(items, text.highlight("MajuPopupActionDisabled")("_"))
  else
    for i, key in ipairs(action.keys) do
      table.insert(items, text.highlight("MajuPopupActionKey")(key))
      if i < #action.keys then
        table.insert(items, text(","))
      end
    end
  end

  table.insert(items, text(" "))
  table.insert(items, text(action.description))

  return items
end

local Actions = Component.new(function(props)
  return col {
    Grid.padding_left(1) {
      items = props.state,
      gap = 3,
      render_item = function(item)
        if item.heading then
          return row.highlight("MajuPopupSectionTitle") { text(item.heading) }
        elseif not item.callback then
          return row.highlight("MajuPopupActionDisabled")(render_action(item))
        else
          return row(render_action(item))
        end
      end,
    },
  }
end)

function M.items(state)
  local items = {}

  if state.args[1] then
    local section = {}
    local name = "Arguments"
    for _, item in ipairs(state.args) do
      if item.type == "option" then
        table.insert(section, Option(item))
      elseif item.type == "switch" then
        table.insert(section, Switch(item))
      elseif item.type == "heading" then
        if section[1] then
          table.insert(items, Section(name, section))
          table.insert(items, EmptyLine())
          section = {}
        end
        name = item.heading
      end
    end

    table.insert(items, Section(name, section))
    table.insert(items, EmptyLine())
  end

  if state.actions[1] then
    table.insert(items, Actions { state = state.actions })
  end

  return items
end

function M.Popup(state)
  return {
    List {
      items = M.items(state),
    },
  }
end

return M
