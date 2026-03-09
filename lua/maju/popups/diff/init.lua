local popup = require("maju.lib.popup")
local actions = require("maju.popups.diff.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuDiff")
    :option("r", "revision", "@", "Revision")
    :group_heading("Diff")
    :action("d", "View diff", actions.view_diff)
    :action("s", "Show stat", actions.show_stat)
    :build()

  p:show()
end

return M
