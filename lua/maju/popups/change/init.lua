local popup = require("maju.lib.popup")
local actions = require("maju.popups.change.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuChange")
    :group_heading("Create")
    :action("n", "New", actions.new_change)
    :action("N", "New before", actions.new_before)
    :new_action_group("Edit")
    :action("e", "Edit", actions.edit_change)
    :action("d", "Describe", actions.describe_change)
    :action("a", "Abandon", actions.abandon_change)
    :new_action_group()
    :action("D", "Duplicate", actions.duplicate_change)
    :build()

  p:show()
end

return M
