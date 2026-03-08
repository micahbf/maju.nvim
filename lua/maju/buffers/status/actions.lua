local notification = require("maju.lib.notification")
local input = require("maju.lib.input")
local squash = require("maju.lib.jj.squash")

local M = {}

local function status_instance()
  return require("maju.buffers.status").instance
end

local function refresh()
  local instance = status_instance()
  if instance then
    instance:refresh()
  end
end

--- Get the item (file) under cursor from the UI
---@param buffer Buffer
---@return table|nil item, string|nil section_name
local function get_item_and_section(buffer)
  local item = buffer.ui:get_item_under_cursor()
  local section = buffer.ui:get_current_section()
  local section_name = section and section.options.section
  return item, section_name
end

--- Collect file names from selection items
---@param items table[]
---@return string[]
local function collect_filenames(items)
  local names = {}
  for _, item in ipairs(items) do
    if item.name then
      table.insert(names, item.name)
    end
  end
  return names
end

-- Toggle fold under cursor
function M.toggle(buffer)
  local fold = buffer.ui:get_fold_under_cursor()
  if not fold then
    return
  end

  fold.options.folded = not fold.options.folded

  -- Trigger on_open callback for lazy diff loading
  if not fold.options.folded and fold.options.on_open then
    fold.options.on_open(fold, buffer.ui)
  end

  buffer.ui:update()
end

-- Go to file under cursor
function M.goto_file(buffer)
  local component = buffer.ui:get_hunk_or_filename_under_cursor()
  if not component then
    return
  end

  local filename = component.filename
  if not filename then
    return
  end

  local instance = status_instance()
  if not instance then
    return
  end

  local cursor = nil
  local hunk = component.hunk
  if hunk then
    local line = buffer:cursor_line()
    if line >= hunk.first and line <= hunk.last then
      local offset = line - hunk.first
      local row = hunk.disk_from + offset
      -- Adjust for removed lines
      for i = 1, math.min(offset, #hunk.lines) do
        local hline = hunk.lines[i]
        if hline and hline:sub(1, 1) == "-" then
          row = row - 1
        end
      end
      cursor = { math.max(1, row), 0 }
    end
  end

  local path = instance.root .. "/" .. filename
  buffer:hide()

  if cursor then
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end
end

-- Jump to previous section
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

-- Jump to next section
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

-- Squash selected file/hunk from @ to @- (normal mode)
function M.squash(buffer)
  local item, section_name = get_item_and_section(buffer)
  if not item or not item.name then
    return
  end

  if section_name ~= "working_copy" then
    notification.warn("Can only squash from working copy changes")
    return
  end

  local result = squash.squash_files({ item.name })
  if result.success then
    notification.info("Squashed: " .. item.name)
    refresh()
  else
    notification.error("Squash failed: " .. (result.error or "unknown"))
  end
end

-- Unsquash selected file/hunk from @- back to @ (normal mode)
function M.unsquash(buffer)
  local item, section_name = get_item_and_section(buffer)
  if not item or not item.name then
    return
  end

  if section_name ~= "parent" then
    notification.warn("Can only unsquash from parent changes")
    return
  end

  local result = squash.unsquash_files({ item.name })
  if result.success then
    notification.info("Unsquashed: " .. item.name)
    refresh()
  else
    notification.error("Unsquash failed: " .. (result.error or "unknown"))
  end
end

-- Restore/discard selected file (normal mode)
function M.restore(buffer)
  local item, section_name = get_item_and_section(buffer)
  if not item or not item.name then
    return
  end

  if section_name ~= "working_copy" then
    notification.warn("Can only restore working copy changes")
    return
  end

  local confirmed = input.get_confirmation("Discard changes to " .. item.name .. "?")
  if not confirmed then
    return
  end

  local result = squash.restore_files({ item.name })
  if result.success then
    notification.info("Restored: " .. item.name)
    refresh()
  else
    notification.error("Restore failed: " .. (result.error or "unknown"))
  end
end

-- Visual mode squash
function M.v_squash(buffer)
  local selection = buffer.ui:get_selection()
  if not selection or not selection.section then
    return
  end

  if selection.section.options and selection.section.options.section ~= "working_copy" then
    notification.warn("Can only squash from working copy changes")
    return
  end

  local names = collect_filenames(selection.items)
  if #names == 0 then
    return
  end

  local result = squash.squash_files(names)
  if result.success then
    notification.info(string.format("Squashed %d file(s)", #names))
    refresh()
  else
    notification.error("Squash failed: " .. (result.error or "unknown"))
  end
end

-- Visual mode unsquash
function M.v_unsquash(buffer)
  local selection = buffer.ui:get_selection()
  if not selection or not selection.section then
    return
  end

  if selection.section.options and selection.section.options.section ~= "parent" then
    notification.warn("Can only unsquash from parent changes")
    return
  end

  local names = collect_filenames(selection.items)
  if #names == 0 then
    return
  end

  local result = squash.unsquash_files(names)
  if result.success then
    notification.info(string.format("Unsquashed %d file(s)", #names))
    refresh()
  else
    notification.error("Unsquash failed: " .. (result.error or "unknown"))
  end
end

-- Visual mode restore
function M.v_restore(buffer)
  local selection = buffer.ui:get_selection()
  if not selection or not selection.section then
    return
  end

  if selection.section.options and selection.section.options.section ~= "working_copy" then
    notification.warn("Can only restore working copy changes")
    return
  end

  local names = collect_filenames(selection.items)
  if #names == 0 then
    return
  end

  local confirmed = input.get_confirmation(string.format("Discard changes to %d file(s)?", #names))
  if not confirmed then
    return
  end

  local result = squash.restore_files(names)
  if result.success then
    notification.info(string.format("Restored %d file(s)", #names))
    refresh()
  else
    notification.error("Restore failed: " .. (result.error or "unknown"))
  end
end

-- Open change popup
function M.change_popup()
  require("maju.popups.change").create()
end

-- Open bookmark popup
function M.bookmark_popup()
  require("maju.popups.bookmark").create()
end

-- Open help popup
function M.help_popup()
  require("maju.popups.help").create()
end

-- Refresh status buffer
function M.refresh()
  refresh()
end

-- Close status buffer
function M.close()
  local instance = status_instance()
  if instance then
    instance:close()
  end
end

-- Show command history
function M.command_history()
  local jj = require("maju.lib.jj.cli")
  local items = {}
  for i = #jj.history, math.max(1, #jj.history - 50), -1 do
    local entry = jj.history[i]
    if entry then
      table.insert(items, string.format("[%d] %s", entry.code, entry.cmd))
    end
  end

  if #items == 0 then
    notification.info("No command history")
    return
  end

  vim.ui.select(items, { prompt = "Command History" }, function() end)
end

-- Yank change ID under cursor
function M.yank(buffer)
  local yankable = buffer.ui:get_yankable_under_cursor()
  if yankable then
    vim.fn.setreg("+", yankable)
    vim.fn.setreg('"', yankable)
    notification.info("Yanked: " .. yankable)
  end
end

return M
