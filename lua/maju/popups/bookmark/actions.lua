local bookmark = require("maju.lib.jj.bookmark")
local input = require("maju.lib.input")
local notification = require("maju.lib.notification")

local M = {}

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

function M.create_bookmark(popup)
  local name = input.get_user_input("Bookmark name")
  if not name or name == "" then
    return
  end

  local result = bookmark.create(name, "@")
  if result.success then
    notification.info("Created bookmark: " .. name)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.set_bookmark(popup)
  local name = input.get_user_input("Set bookmark")
  if not name or name == "" then
    return
  end

  local rev = input.get_user_input("Set to revision", { default = "@" })
  if not rev then
    return
  end

  local result = bookmark.set(name, rev)
  if result.success then
    notification.info("Set bookmark " .. name .. " to " .. rev)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.move_bookmark(popup)
  local name = input.get_user_input("Move bookmark")
  if not name or name == "" then
    return
  end

  local rev = input.get_user_input("Move to revision", { default = "@" })
  if not rev then
    return
  end

  local result = bookmark.move(name, { to = rev })
  if result.success then
    notification.info("Moved bookmark " .. name)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.delete_bookmark(popup)
  local name = input.get_user_input("Delete bookmark")
  if not name or name == "" then
    return
  end

  local confirmed = input.get_confirmation("Delete bookmark '" .. name .. "'?")
  if not confirmed then
    return
  end

  local result = bookmark.delete(name)
  if result.success then
    notification.info("Deleted bookmark: " .. name)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.rename_bookmark(popup)
  local old = input.get_user_input("Rename bookmark (old name)")
  if not old or old == "" then
    return
  end

  local new = input.get_user_input("New name")
  if not new or new == "" then
    return
  end

  local result = bookmark.rename(old, new)
  if result.success then
    notification.info("Renamed bookmark: " .. old .. " -> " .. new)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.track_bookmark(popup)
  local name = input.get_user_input("Track bookmark (e.g. main@origin)")
  if not name or name == "" then
    return
  end

  local result = bookmark.track(name)
  if result.success then
    notification.info("Tracking: " .. name)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

function M.untrack_bookmark(popup)
  local name = input.get_user_input("Untrack bookmark (e.g. main@origin)")
  if not name or name == "" then
    return
  end

  local result = bookmark.untrack(name)
  if result.success then
    notification.info("Untracked: " .. name)
    refresh_status()
  else
    notification.error("Failed: " .. (result.error or "unknown error"))
  end
end

return M
