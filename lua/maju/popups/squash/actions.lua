local squash = require("maju.lib.jj.squash")
local change = require("maju.lib.jj.change")
local repository = require("maju.lib.jj.repository")
local input = require("maju.lib.input")
local notification = require("maju.lib.notification")
local terminal = require("maju.lib.terminal")

local M = {}

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

local function get_switch_enabled(popup, cli_name)
  for _, arg in pairs(popup.state.args) do
    if arg.type == "switch" and arg.cli == cli_name then
      return arg.enabled
    end
  end
  return false
end

function M.squash_to_parent(popup)
  if repository.state.parent_immutable then
    notification.warn("Cannot squash: parent revision is immutable")
    return
  end

  local interactive = get_switch_enabled(popup, "interactive")

  if interactive then
    terminal.run({ "jj", "--no-pager", "squash", "-i" }, {
      on_exit = function()
        refresh_status()
      end,
    })
    return
  end

  local result = squash.squash({})
  if result.success then
    notification.info("Squashed to parent")
    refresh_status()
  else
    notification.error("Squash failed: " .. (result.error or "unknown error"))
  end
end

function M.squash_into(popup)
  local dest = input.get_user_input("Squash into revision")
  if not dest or dest == "" then
    return
  end

  if change.is_immutable(dest) then
    notification.warn("Cannot squash: target revision is immutable")
    return
  end

  local interactive = get_switch_enabled(popup, "interactive")

  if interactive then
    terminal.run({ "jj", "--no-pager", "squash", "--into", dest, "-i" }, {
      on_exit = function()
        refresh_status()
      end,
    })
    return
  end

  local result = squash.squash({ into = dest })
  if result.success then
    notification.info("Squashed into " .. dest)
    refresh_status()
  else
    notification.error("Squash failed: " .. (result.error or "unknown error"))
  end
end

function M.move_to(popup)
  local dest = input.get_user_input("Move changes to revision")
  if not dest or dest == "" then
    return
  end

  if change.is_immutable(dest) then
    notification.warn("Cannot squash: target revision is immutable")
    return
  end

  local interactive = get_switch_enabled(popup, "interactive")

  if interactive then
    terminal.run({ "jj", "--no-pager", "squash", "--from", "@", "--into", dest, "-i" }, {
      on_exit = function()
        refresh_status()
      end,
    })
    return
  end

  local result = squash.squash({ from = "@", into = dest })
  if result.success then
    notification.info("Moved changes to " .. dest)
    refresh_status()
  else
    notification.error("Squash failed: " .. (result.error or "unknown error"))
  end
end

return M
