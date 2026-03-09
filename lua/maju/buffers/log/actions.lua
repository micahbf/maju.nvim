local change = require("maju.lib.jj.change")
local input = require("maju.lib.input")
local notification = require("maju.lib.notification")

local M = {}

local function log_instance()
  return require("maju.buffers.log").instance
end

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

function M.open_change(buffer)
  local change_id = buffer.ui:get_change_under_cursor()
  if not change_id then
    return
  end

  local instance = log_instance()
  if not instance then
    return
  end

  require("maju.buffers.change").open(instance.root, change_id)
end

function M.edit_revision(buffer)
  local change_id = buffer.ui:get_change_under_cursor()
  if not change_id then
    return
  end

  if change.is_immutable(change_id) then
    notification.warn("Cannot edit: revision is immutable")
    return
  end

  local result = change.edit(change_id)
  if result.success then
    notification.info("Now editing " .. change_id)
    refresh_status()
    local instance = log_instance()
    if instance then
      instance:refresh()
    end
  else
    notification.error("Edit failed: " .. (result.error or "unknown"))
  end
end

function M.describe_revision(buffer)
  local change_id = buffer.ui:get_change_under_cursor()
  if not change_id then
    return
  end

  if change.is_immutable(change_id) then
    notification.warn("Cannot describe: revision is immutable")
    return
  end

  local instance = log_instance()
  if not instance then
    return
  end

  require("maju.buffers.describe").open(instance.root, change_id, {
    on_complete = function()
      refresh_status()
      local inst = log_instance()
      if inst then
        inst:refresh()
      end
    end,
  })
end

function M.diff_popup()
  require("maju.popups.diff").create()
end

function M.rebase_popup()
  require("maju.popups.rebase").create()
end

function M.bookmark_popup()
  require("maju.popups.bookmark").create()
end

function M.change_popup()
  require("maju.popups.change").create()
end

function M.change_revset()
  local instance = log_instance()
  if not instance then
    return
  end

  local current = instance.revset or ""
  local revset = input.get_user_input("Revset filter", { default = current })
  if revset == nil then
    return
  end

  if revset == "" then
    revset = nil
  end

  instance:set_revset(revset)
end

function M.refresh()
  local instance = log_instance()
  if instance then
    instance:refresh()
  end
end

function M.close()
  local instance = log_instance()
  if instance then
    instance:close()
  end
end

function M.prev_entry(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  -- Find previous line with a change_id
  for line = cursor - 1, 1, -1 do
    local component = buffer.ui:_find_component_by_index(line, function(node)
      return node.options.change_id ~= nil
    end)
    if component then
      buffer:move_cursor(line)
      return
    end
  end
end

function M.next_entry(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local line_count = buffer:line_count()
  -- Find next line with a change_id
  for line = cursor + 1, line_count do
    local component = buffer.ui:_find_component_by_index(line, function(node)
      return node.options.change_id ~= nil
    end)
    if component then
      buffer:move_cursor(line)
      return
    end
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

function M.help_popup()
  require("maju.popups.help").create()
end

return M
