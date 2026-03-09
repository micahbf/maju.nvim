local operation = require("maju.lib.jj.operation")
local notification = require("maju.lib.notification")
local input = require("maju.lib.input")

local M = {}

local function oplog_instance()
  return require("maju.buffers.oplog").instance
end

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

function M.restore(buffer)
  local yankable = buffer.ui:get_yankable_under_cursor()
  if not yankable then
    return
  end

  local confirmed = input.get_confirmation("Restore to operation " .. yankable .. "?")
  if not confirmed then
    return
  end

  local result = operation.restore(yankable)
  if result.success then
    notification.info("Restored to operation " .. yankable)
    refresh_status()
    -- Close the oplog buffer after restore
    local instance = oplog_instance()
    if instance then
      instance:close()
    end
  else
    notification.error("Restore failed: " .. (result.error or "unknown"))
  end
end

function M.refresh(buffer)
  local instance = oplog_instance()
  if instance then
    instance:refresh()
  end
end

function M.close()
  local instance = oplog_instance()
  if instance then
    instance:close()
  end
end

function M.yank(buffer)
  local yankable = buffer.ui:get_yankable_under_cursor()
  if yankable then
    vim.fn.setreg("+", yankable)
    vim.fn.setreg('"', yankable)
    notification.info("Yanked: " .. yankable)
  end
end

function M.prev_entry(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local item_index = buffer.ui.item_index

  for i = #item_index, 1, -1 do
    if item_index[i].first and item_index[i].first < cursor then
      buffer:move_cursor(item_index[i].first)
      return
    end
  end
end

function M.next_entry(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local item_index = buffer.ui.item_index

  for i = 1, #item_index do
    if item_index[i].first and item_index[i].first > cursor then
      buffer:move_cursor(item_index[i].first)
      return
    end
  end
end

return M
