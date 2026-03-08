local popup = require("maju.lib.popup")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuHelp")
    :group_heading("Navigation")
    :action({ "<tab>" }, "Toggle fold")
    :action({ "<cr>" }, "Go to file")
    :action({ "{" }, "Previous section")
    :action({ "}" }, "Next section")
    :new_action_group("Hunk operations")
    :action({ "S" }, "Squash to parent")
    :action({ "U" }, "Unsquash from parent")
    :action({ "x" }, "Restore/discard")
    :new_action_group("Popups")
    :action({ "c" }, "Change popup")
    :action({ "b" }, "Bookmark popup")
    :action({ "?" }, "Help")
    :new_action_group("Other")
    :action({ "g" }, "Refresh")
    :action({ "q" }, "Close buffer")
    :action({ "$" }, "Command history")
    :action({ "y" }, "Yank change ID")
    :build()

  p:show()
end

return M
