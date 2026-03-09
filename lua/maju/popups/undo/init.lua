local popup = require("maju.lib.popup")
local actions = require("maju.popups.undo.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuUndo")
    :group_heading("Operations")
    :action("u", "Undo", actions.undo)
    :action("r", "Redo", actions.redo)
    :action("l", "Operation log", actions.op_log)
    :build()

  p:show()
end

return M
