local popup = require("maju.lib.popup")
local actions = require("maju.popups.split.actions")

local M = {}

function M.create()
  local p = popup.builder()
    :name("MajuSplit")
    :option("r", "revision", "@", "Revision")
    :group_heading("Split")
    :action("s", "Split interactively", actions.split_interactive)
    :action("S", "Split at file level", actions.split_by_files)
    :build()

  p:show()
end

return M
