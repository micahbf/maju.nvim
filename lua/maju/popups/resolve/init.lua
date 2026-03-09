local popup = require("maju.lib.popup")
local actions = require("maju.popups.resolve.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuResolve")
    :option("t", "tool", "", "Merge tool")
    :group_heading("Resolve")
    :action("r", "Resolve conflicts", actions.resolve)
    :build()

  p:show()
end

return M
