local operation = require("maju.lib.jj.operation")
local notification = require("maju.lib.notification")

local M = {}

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

function M.undo(popup)
  local result = operation.undo()
  if result.success then
    notification.info("Undo successful")
    refresh_status()
  else
    notification.error("Undo failed: " .. (result.error or "unknown error"))
  end
end

function M.redo(popup)
  local result = operation.redo()
  if result.success then
    notification.info("Redo successful")
    refresh_status()
  else
    notification.error("Redo failed: " .. (result.error or "unknown error"))
  end
end

function M.op_log(popup)
  local jj = require("maju.lib.jj.cli")
  local root = jj._root
  if not root then
    notification.error("No repository root")
    return
  end
  require("maju.buffers.oplog").open(root)
end

return M
