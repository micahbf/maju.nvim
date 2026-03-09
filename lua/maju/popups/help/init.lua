local popup = require("maju.lib.popup")

local M = {}

--- Create a callback that opens another popup after closing help
local function open_popup(name)
  return function()
    require("maju.popups." .. name).create()
  end
end

--- No-op callback to prevent "not implemented" warning for display-only keys
local function noop()
end

function M.create()
  local p = popup.builder()
    :name("MajuHelp")
    :group_heading("Navigation")
    :action({ "<tab>" }, "Toggle fold", noop)
    :action({ "<cr>" }, "Go to file / open change", noop)
    :action({ "{" }, "Previous section", noop)
    :action({ "}" }, "Next section", noop)
    :new_action_group("Hunk operations")
    :action({ "S" }, "Squash to parent", noop)
    :action({ "U" }, "Unsquash from parent", noop)
    :action({ "x" }, "Restore/discard", noop)
    :new_action_group("Popups")
    :action({ "c" }, "Change popup", open_popup("change"))
    :action({ "b" }, "Bookmark popup", open_popup("bookmark"))
    :action({ "s" }, "Squash popup", open_popup("squash"))
    :action({ "r" }, "Rebase popup", open_popup("rebase"))
    :action({ "P" }, "Push popup", open_popup("push"))
    :action({ "f" }, "Fetch popup", open_popup("fetch"))
    :action({ "X" }, "Undo popup", open_popup("undo"))
    :action({ "d" }, "Diff popup", open_popup("diff"))
    :action({ "p" }, "Split popup", open_popup("split"))
    :action({ "?" }, "Help", noop)
    :new_action_group("Buffers")
    :action({ "l" }, "Log view", function()
      local instance = require("maju.buffers.status").instance
      if instance then
        require("maju.buffers.log").open(instance.root)
      end
    end)
    :new_action_group("Other")
    :action({ "g" }, "Refresh", noop)
    :action({ "q" }, "Close buffer")
    :action({ "$" }, "Command history", noop)
    :action({ "y" }, "Yank change ID", noop)
    :build()

  p:show()
end

return M
