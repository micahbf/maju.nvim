local popup = require("maju.lib.popup")
local actions = require("maju.popups.fetch.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuFetch")
    :option("r", "remote", "", "Remote")
    :group_heading("Fetch")
    :action("f", "Fetch", actions.fetch)
    :action("F", "Fetch all remotes", actions.fetch_all)
    :build()

  p:show()
end

return M
