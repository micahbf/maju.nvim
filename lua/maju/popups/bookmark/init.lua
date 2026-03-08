local popup = require("maju.lib.popup")
local actions = require("maju.popups.bookmark.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuBookmark")
    :group_heading("Create")
    :action("c", "Create", actions.create_bookmark)
    :action("s", "Set", actions.set_bookmark)
    :action("m", "Move", actions.move_bookmark)
    :new_action_group("Delete")
    :action("d", "Delete", actions.delete_bookmark)
    :action("r", "Rename", actions.rename_bookmark)
    :new_action_group("Track")
    :action("t", "Track", actions.track_bookmark)
    :action("T", "Untrack", actions.untrack_bookmark)
    :build()

  p:show()
end

return M
