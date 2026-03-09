local change = require("maju.lib.jj.change")
local input = require("maju.lib.input")
local notification = require("maju.lib.notification")

local M = {}

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

function M.new_change(popup)
  local result = change.new({})
  if result.success then
    notification.info("Created new change")
    refresh_status()
  else
    notification.error("Failed to create change: " .. (result.error or "unknown error"))
  end
end

function M.new_before(popup)
  local result = change.new({ insert_before = true })
  if result.success then
    notification.info("Created new change before @")
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.edit_change(popup)
  local rev = input.get_user_input("Edit revision")
  if not rev or rev == "" then
    return
  end

  if change.is_immutable(rev) then
    notification.warn("Cannot edit: revision is immutable")
    return
  end

  local result = change.edit(rev)
  if result.success then
    notification.info("Now editing " .. rev)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.describe_change(popup)
  local jj = require("maju.lib.jj.cli")
  local root = jj._root
  if not root then
    notification.error("No repository root")
    return
  end

  require("maju.buffers.describe").open(root, "@", {
    on_complete = function()
      refresh_status()
    end,
  })
end

function M.abandon_change(popup)
  if change.is_immutable("@") then
    notification.warn("Cannot abandon: working copy revision is immutable")
    return
  end

  local confirmed = input.get_confirmation("Abandon working copy change?")
  if not confirmed then
    return
  end

  local result = change.abandon("@")
  if result.success then
    notification.info("Change abandoned")
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.duplicate_change(popup)
  local rev = input.get_user_input("Duplicate revision", { default = "@" })
  if not rev or rev == "" then
    return
  end

  local result = change.duplicate({ rev })
  if result.success then
    notification.info("Change duplicated")
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

return M
