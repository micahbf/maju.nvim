local remote = require("maju.lib.jj.remote")
local notification = require("maju.lib.notification")

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

local function get_option_value(popup, cli_name)
  for _, arg in pairs(popup.state.args) do
    if arg.type == "option" and arg.cli == cli_name then
      return (arg.value and arg.value ~= "") and arg.value or nil
    end
  end
end

function M.push(popup)
  local opts = {
    all = get_switch_enabled(popup, "all"),
    deleted = get_switch_enabled(popup, "deleted"),
    remote = get_option_value(popup, "remote"),
  }

  notification.info("Pushing...")
  local result = remote.push(opts)
  if result.success then
    if result.output then
      notification.info(result.output)
    else
      notification.info("Push complete")
    end
    refresh_status()
  else
    notification.error("Push failed: " .. (result.error or "unknown error"))
  end
end

function M.push_all(popup)
  notification.info("Pushing all bookmarks...")
  local result = remote.push({ all = true })
  if result.success then
    if result.output then
      notification.info(result.output)
    else
      notification.info("Push complete (all bookmarks)")
    end
    refresh_status()
  else
    notification.error("Push failed: " .. (result.error or "unknown error"))
  end
end

return M
