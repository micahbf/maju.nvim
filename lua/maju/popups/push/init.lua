local popup = require("maju.lib.popup")
local actions = require("maju.popups.push.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuPush")
    :switch("a", "all", "Push all bookmarks")
    :switch("d", "deleted", "Include deleted bookmarks")
    :option("r", "remote", "", "Remote")
    :group_heading("Push")
    :action("p", "Push", actions.push)
    :action("P", "Push all", actions.push_all)
    :build()

  p:show()
end

return M
