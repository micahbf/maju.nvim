local popup = require("maju.lib.popup")
local actions = require("maju.popups.rebase.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuRebase")
    :option("r", "revision", "@", "Revision to rebase")
    :group_heading("Rebase")
    :action("d", "Onto destination", actions.rebase_destination)
    :action("A", "After revision", actions.rebase_after)
    :action("B", "Before revision", actions.rebase_before)
    :build()

  p:show()
end

return M
