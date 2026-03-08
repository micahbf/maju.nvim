local notification = require("maju.lib.notification")
local input = require("maju.lib.input")
local squash = require("maju.lib.jj.squash")
local repository = require("maju.lib.jj.repository")

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

--- Check if parent is immutable and show warning for squash operations
---@param section_name string
---@return boolean true if blocked
local function check_immutable(section_name)
  if section_name == "working_copy" and repository.state.parent_immutable then
    notification.warn("Cannot squash: parent revision is immutable")
    return true
  end
  if section_name == "parent" and repository.state.parent_immutable then
    notification.warn("Cannot unsquash: parent revision is immutable")
    return true
  end
  return false
end

--- Check if this is a merge commit and block squash operations
---@return boolean true if blocked
local function check_merge()
  if #repository.state.parents > 1 then
    notification.warn("Squash on merge commits not yet supported")
    return true
  end
  return false
end

--- Determine operation context: file-level or hunk-level
---@param buffer Buffer
---@return {scope: string, item: table|nil, hunk: table|nil, section_name: string|nil}
local function get_operation_context(buffer)
  local hunk_or_file = buffer.ui:get_hunk_or_filename_under_cursor()
  local item = buffer.ui:get_item_under_cursor()
  local section = buffer.ui:get_current_section()
  local section_name = section and section.options.section

  local hunk = hunk_or_file and hunk_or_file.hunk
  local scope = "file"

  if hunk and item and rawget(item, "diff") then
    scope = "hunk"
  end

  return {
    scope = scope,
    item = item,
    hunk = hunk,
    section_name = section_name,
  }
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
  local ctx = get_operation_context(buffer)
  if not ctx.item or not ctx.item.name then
    return
  end

  if ctx.section_name ~= "working_copy" then
    notification.warn("Can only squash from working copy changes")
    return
  end

  if check_immutable(ctx.section_name) or check_merge() then
    return
  end

  local result
  if ctx.scope == "hunk" and ctx.hunk then
    result = squash.squash_hunks(ctx.item.name, { ctx.hunk }, ctx.item.diff)
  else
    result = squash.squash_files({ ctx.item.name })
  end

  if result.success then
    local label = ctx.scope == "hunk" and "Squashed hunk: " or "Squashed: "
    notification.info(label .. ctx.item.name)
    refresh()
  else
    notification.error("Squash failed: " .. (result.error or "unknown"))
  end
end

-- Unsquash selected file/hunk from @- back to @ (normal mode)
function M.unsquash(buffer)
  local ctx = get_operation_context(buffer)
  if not ctx.item or not ctx.item.name then
    return
  end

  if ctx.section_name ~= "parent" then
    notification.warn("Can only unsquash from parent changes")
    return
  end

  if check_immutable(ctx.section_name) or check_merge() then
    return
  end

  local result
  if ctx.scope == "hunk" and ctx.hunk then
    result = squash.unsquash_hunks(ctx.item.name, { ctx.hunk }, ctx.item.diff)
  else
    result = squash.unsquash_files({ ctx.item.name })
  end

  if result.success then
    local label = ctx.scope == "hunk" and "Unsquashed hunk: " or "Unsquashed: "
    notification.info(label .. ctx.item.name)
    refresh()
  else
    notification.error("Unsquash failed: " .. (result.error or "unknown"))
  end
end

-- Restore/discard selected file or hunk (normal mode)
function M.restore(buffer)
  local ctx = get_operation_context(buffer)
  if not ctx.item or not ctx.item.name then
    return
  end

  if ctx.section_name ~= "working_copy" then
    notification.warn("Can only restore working copy changes")
    return
  end

  local label = ctx.scope == "hunk" and "hunk in " or "changes to "
  local confirmed = input.get_confirmation("Discard " .. label .. ctx.item.name .. "?")
  if not confirmed then
    return
  end

  local result
  if ctx.scope == "hunk" and ctx.hunk then
    local instance = status_instance()
    result = squash.restore_hunks(instance.root, ctx.item.name, { ctx.hunk }, ctx.item.diff)
  else
    result = squash.restore_files({ ctx.item.name })
  end

  if result.success then
    notification.info("Restored: " .. ctx.item.name)
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

  if check_immutable("working_copy") or check_merge() then
    return
  end

  -- Check if selection is within a single item with expanded diff (hunk-level)
  if selection.item and rawget(selection.item, "diff") and selection.item.diff then
    local partial = selection.first_line > selection.item.first
    local hunks = buffer.ui:item_hunks(selection.item, selection.first_line, selection.last_line, partial)
    if #hunks > 0 then
      local result
      if partial and #hunks == 1 then
        result = squash.squash_hunks(selection.item.name, hunks, selection.item.diff, {
          partial = true,
          sel_from = hunks[1].from,
          sel_to = hunks[1].to,
        })
      else
        -- Extract raw hunks from SelectedHunk wrappers
        local raw_hunks = {}
        for _, h in ipairs(hunks) do
          table.insert(raw_hunks, h.hunk or h)
        end
        result = squash.squash_hunks(selection.item.name, raw_hunks, selection.item.diff)
      end

      if result.success then
        notification.info("Squashed hunk(s): " .. selection.item.name)
        refresh()
      else
        notification.error("Squash failed: " .. (result.error or "unknown"))
      end
      return
    end
  end

  -- Fall back to file-level squash
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

  if check_immutable("parent") or check_merge() then
    return
  end

  -- Check if selection is within a single item with expanded diff (hunk-level)
  if selection.item and rawget(selection.item, "diff") and selection.item.diff then
    local partial = selection.first_line > selection.item.first
    local hunks = buffer.ui:item_hunks(selection.item, selection.first_line, selection.last_line, partial)
    if #hunks > 0 then
      local result
      if partial and #hunks == 1 then
        result = squash.unsquash_hunks(selection.item.name, hunks, selection.item.diff, {
          partial = true,
          sel_from = hunks[1].from,
          sel_to = hunks[1].to,
        })
      else
        local raw_hunks = {}
        for _, h in ipairs(hunks) do
          table.insert(raw_hunks, h.hunk or h)
        end
        result = squash.unsquash_hunks(selection.item.name, raw_hunks, selection.item.diff)
      end

      if result.success then
        notification.info("Unsquashed hunk(s): " .. selection.item.name)
        refresh()
      else
        notification.error("Unsquash failed: " .. (result.error or "unknown"))
      end
      return
    end
  end

  -- Fall back to file-level unsquash
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

  -- Check if selection is within a single item with expanded diff (hunk-level)
  if selection.item and rawget(selection.item, "diff") and selection.item.diff then
    local partial = selection.first_line > selection.item.first
    local hunks = buffer.ui:item_hunks(selection.item, selection.first_line, selection.last_line, partial)
    if #hunks > 0 then
      local confirmed = input.get_confirmation("Discard selected hunk(s) in " .. selection.item.name .. "?")
      if not confirmed then
        return
      end

      local instance = status_instance()
      local result
      if partial and #hunks == 1 then
        result = squash.restore_hunks(instance.root, selection.item.name, hunks, selection.item.diff, {
          partial = true,
          sel_from = hunks[1].from,
          sel_to = hunks[1].to,
        })
      else
        local raw_hunks = {}
        for _, h in ipairs(hunks) do
          table.insert(raw_hunks, h.hunk or h)
        end
        result = squash.restore_hunks(instance.root, selection.item.name, raw_hunks, selection.item.diff)
      end

      if result.success then
        notification.info("Restored hunk(s): " .. selection.item.name)
        refresh()
      else
        notification.error("Restore failed: " .. (result.error or "unknown"))
      end
      return
    end
  end

  -- Fall back to file-level restore
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
