local Buffer = require("maju.lib.buffer")
local config = require("maju.config")
local ui = require("maju.buffers.status.ui")
local repository = require("maju.lib.jj.repository")
local notification = require("maju.lib.notification")

---@class StatusBuffer
---@field buffer Buffer|nil
---@field root string
---@field fold_state table|nil
---@field cursor_state number|nil
---@field view_state table|nil
---@field _refreshing boolean
---@field _debounce_timer uv_timer_t|nil
local M = {}
M.__index = M

M.instance = nil

---@param root string
---@param kind? string
function M.open(root, kind)
  if M.instance and M.instance.buffer and M.instance.buffer:is_visible() then
    M.instance.buffer:focus()
    return
  end

  local instance = setmetatable({
    root = root,
    buffer = nil,
    fold_state = nil,
    cursor_state = nil,
    view_state = nil,
    _refreshing = false,
    _debounce_timer = nil,
  }, M)

  M.instance = instance

  repository.refresh(root)

  local actions = require("maju.buffers.status.actions")

  instance.buffer = Buffer.create {
    name = "MajuStatus",
    filetype = "MajuStatus",
    kind = kind or config.values.kind or "tab",
    cwd = root,
    context_highlight = true,
    foldmarkers = true,
    disable_line_numbers = config.values.disable_line_numbers,
    disable_relative_line_numbers = config.values.disable_relative_line_numbers,
    on_detach = function()
      if M.instance == instance then
        M.instance = nil
      end
    end,
    mappings = {
      n = {
        ["<tab>"] = actions.toggle,
        ["<cr>"] = actions.goto_file,
        ["{"] = actions.prev_section,
        ["}"] = actions.next_section,
        ["S"] = actions.squash,
        ["U"] = actions.unsquash,
        ["x"] = actions.restore,
        ["c"] = actions.change_popup,
        ["b"] = actions.bookmark_popup,
        ["?"] = actions.help_popup,
        ["g"] = actions.refresh,
        ["q"] = actions.close,
        ["$"] = actions.command_history,
        ["y"] = actions.yank,
      },
      v = {
        ["S"] = actions.v_squash,
        ["U"] = actions.v_unsquash,
        ["x"] = actions.v_restore,
      },
    },
    render = function()
      return ui.render(repository.state)
    end,
    after = function(buf)
      local first = buf.ui:first_section()
      if first then
        buf:move_cursor(first.first)
      end
    end,
  }
end

function M:refresh()
  if not self.buffer then
    return
  end

  -- Prevent overlapping refreshes
  if self._refreshing then
    return
  end

  -- Cancel pending debounce timer
  if self._debounce_timer then
    self._debounce_timer:stop()
    self._debounce_timer:close()
    self._debounce_timer = nil
  end

  -- Debounce: delay 100ms to coalesce rapid refresh calls
  self._debounce_timer = vim.uv.new_timer()
  self._debounce_timer:start(100, 0, vim.schedule_wrap(function()
    self._debounce_timer = nil
    self:_do_refresh()
  end))
end

function M:_do_refresh()
  if not self.buffer or self._refreshing then
    return
  end

  self._refreshing = true

  local cursor = self.buffer.ui:get_cursor_location()
  local view = self.buffer:save_view()

  notification.info("Refreshing...")

  repository.refresh_async(self.root, function()
    -- Ensure buffer is still valid
    if not self.buffer then
      self._refreshing = false
      return
    end

    self:redraw(cursor, view)

    vim.api.nvim_exec_autocmds("User", { pattern = "MajuStatusRefreshed" })
    self._refreshing = false
  end)
end

---@param cursor CursorLocation|nil
---@param view table|nil
function M:redraw(cursor, view)
  if not self.buffer then
    return
  end

  self.buffer.ui:render(unpack(ui.render(repository.state)))

  if self.fold_state then
    self.buffer.ui:set_fold_state(self.fold_state)
    self.fold_state = nil
  end

  if self.cursor_state and self.view_state then
    self.buffer:restore_view(self.view_state, self.cursor_state)
    self.view_state = nil
    self.cursor_state = nil
  elseif cursor and view then
    self.buffer:restore_view(view, self.buffer.ui:resolve_cursor_location(cursor))
  end
end

function M:close()
  if self._debounce_timer then
    self._debounce_timer:stop()
    self._debounce_timer:close()
    self._debounce_timer = nil
  end

  if self.buffer then
    self.fold_state = self.buffer.ui:get_fold_state()
    self.cursor_state = self.buffer:cursor_line()
    self.view_state = self.buffer:save_view()
    self.buffer:close()
    self.buffer = nil
  end
end

return M
