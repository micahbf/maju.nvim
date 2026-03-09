local popup = require("maju.lib.popup")
local actions = require("maju.popups.squash.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuSquash")
    :switch("i", "interactive", "Interactive")
    :group_heading("Squash")
    :action("s", "Squash to parent", actions.squash_to_parent)
    :action("S", "Squash into revision", actions.squash_into)
    :action("m", "Move to revision", actions.move_to)
    :build()

  p:show()
end

return M
