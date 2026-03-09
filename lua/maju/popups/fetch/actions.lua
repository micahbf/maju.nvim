local remote = require("maju.lib.jj.remote")
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

function M.fetch(popup)
  local opts = {}
  opts.remote = get_option_value(popup, "remote")

  notification.info("Fetching...")
  local result = remote.fetch(opts)
  if result.success then
    notification.info("Fetch complete")
    refresh_status()
  else
    notification.error("Fetch failed: " .. (result.error or "unknown error"))
  end
end

function M.fetch_all(popup)
  notification.info("Fetching all remotes...")
  local result = remote.fetch({ all_remotes = true })
  if result.success then
    notification.info("Fetch complete (all remotes)")
    refresh_status()
  else
    notification.error("Fetch failed: " .. (result.error or "unknown error"))
  end
end

return M
