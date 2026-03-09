local change_lib = require("maju.lib.jj.change")
local notification = require("maju.lib.notification")

local M = {}

local function change_instance()
  return require("maju.buffers.change").instance
end

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

function M.toggle(buffer)
  local fold = buffer.ui:get_fold_under_cursor()
  if not fold then
    return
  end

  fold.options.folded = not fold.options.folded

  if not fold.options.folded and fold.options.on_open then
    fold.options.on_open(fold, buffer.ui)
  end

  buffer.ui:update()
end

function M.goto_file(buffer)
  local component = buffer.ui:get_hunk_or_filename_under_cursor()
  if not component then
    return
  end

  local filename = component.filename
  if not filename then
    return
  end

  local instance = change_instance()
  if not instance then
    return
  end

  local path = instance.root .. "/" .. filename
  buffer:hide()
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

function M.edit(buffer)
  local instance = change_instance()
  if not instance then
    return
  end

  if change_lib.is_immutable(instance.change_id) then
    notification.warn("Cannot edit: revision is immutable")
    return
  end

  local result = change_lib.edit(instance.change_id)
  if result.success then
    notification.info("Now editing " .. instance.change_id)
    refresh_status()
  else
    notification.error("Edit failed: " .. (result.error or "unknown"))
  end
end

function M.describe(buffer)
  local instance = change_instance()
  if not instance then
    return
  end

  if change_lib.is_immutable(instance.change_id) then
    notification.warn("Cannot describe: revision is immutable")
    return
  end

  require("maju.buffers.describe").open(instance.root, instance.change_id, {
    on_complete = function()
      refresh_status()
      local inst = change_instance()
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

function M.refresh()
  local instance = change_instance()
  if instance then
    instance:refresh()
  end
end

function M.close()
  local instance = change_instance()
  if instance then
    instance:close()
  end
end

function M.prev_section(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local item_index = buffer.ui.item_index

  for i = #item_index, 1, -1 do
    if item_index[i].first and item_index[i].first < cursor then
      buffer:move_cursor(item_index[i].first)
      return
    end
  end
end

function M.next_section(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local item_index = buffer.ui.item_index

  for i = 1, #item_index do
    if item_index[i].first and item_index[i].first > cursor then
      buffer:move_cursor(item_index[i].first)
      return
    end
  end
end

function M.yank(buffer)
  local instance = change_instance()
  if instance then
    vim.fn.setreg("+", instance.change_id)
    vim.fn.setreg('"', instance.change_id)
    notification.info("Yanked: " .. instance.change_id)
  end
end

return M
