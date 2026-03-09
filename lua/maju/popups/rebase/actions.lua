local rebase = require("maju.lib.jj.rebase")
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

local function get_option_value(popup, cli_name)
  for _, arg in pairs(popup.state.args) do
    if arg.type == "option" and arg.cli == cli_name then
      return (arg.value and arg.value ~= "") and arg.value or nil
    end
  end
end

function M.rebase_destination(popup)
  local rev = get_option_value(popup, "revision") or "@"

  if change.is_immutable(rev) then
    notification.warn("Cannot rebase: revision is immutable")
    return
  end

  local dest = input.get_user_input("Rebase " .. rev .. " onto")
  if not dest or dest == "" then
    return
  end

  local result = rebase.rebase({ revision = rev, destination = dest })
  if result.success then
    notification.info("Rebased " .. rev .. " onto " .. dest)
    refresh_status()
  else
    notification.error("Rebase failed: " .. (result.error or "unknown error"))
  end
end

function M.rebase_after(popup)
  local rev = get_option_value(popup, "revision") or "@"

  if change.is_immutable(rev) then
    notification.warn("Cannot rebase: revision is immutable")
    return
  end

  local target = input.get_user_input("Insert " .. rev .. " after")
  if not target or target == "" then
    return
  end

  local result = rebase.rebase({ revision = rev, insert_after = target })
  if result.success then
    notification.info("Rebased " .. rev .. " after " .. target)
    refresh_status()
  else
    notification.error("Rebase failed: " .. (result.error or "unknown error"))
  end
end

function M.rebase_before(popup)
  local rev = get_option_value(popup, "revision") or "@"

  if change.is_immutable(rev) then
    notification.warn("Cannot rebase: revision is immutable")
    return
  end

  local target = input.get_user_input("Insert " .. rev .. " before")
  if not target or target == "" then
    return
  end

  local result = rebase.rebase({ revision = rev, insert_before = target })
  if result.success then
    notification.info("Rebased " .. rev .. " before " .. target)
    refresh_status()
  else
    notification.error("Rebase failed: " .. (result.error or "unknown error"))
  end
end

return M
