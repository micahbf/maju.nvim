local Buffer = require("maju.lib.buffer")
local config = require("maju.config")
local ui = require("maju.buffers.log.ui")
local log = require("maju.lib.jj.log")
local notification = require("maju.lib.notification")

---@class LogBuffer
---@field buffer Buffer|nil
---@field root string
---@field revset string|nil
---@field graph_lines GraphLine[]
---@field _refreshing boolean
---@field _debounce_timer uv_timer_t|nil
local M = {}
M.__index = M

M.instance = nil

---@param root string
---@param kind? string
---@param opts? {revset?: string}
function M.open(root, kind, opts)
  opts = opts or {}

  if M.instance and M.instance.buffer and M.instance.buffer:is_visible() then
    M.instance.buffer:focus()
    return
  end

  local instance = setmetatable({
    root = root,
    buffer = nil,
    revset = opts.revset,
    graph_lines = {},
    _refreshing = false,
    _debounce_timer = nil,
  }, M)

  M.instance = instance

  instance.graph_lines = log.get_graph_log(instance.revset, { limit = 50 })

  local actions = require("maju.buffers.log.actions")

  instance.buffer = Buffer.create {
    name = "MajuLog",
    filetype = "MajuLog",
    kind = kind or config.values.kind or "tab",
    cwd = root,
    context_highlight = false,
    foldmarkers = false,
    disable_line_numbers = config.values.disable_line_numbers,
    disable_relative_line_numbers = config.values.disable_relative_line_numbers,
    on_detach = function()
      if M.instance == instance then
        M.instance = nil
      end
    end,
    mappings = {
      n = {
        ["<cr>"] = actions.open_change,
        ["e"] = actions.edit_revision,
        ["D"] = actions.describe_revision,
        ["d"] = actions.diff_popup,
        ["r"] = actions.rebase_popup,
        ["b"] = actions.bookmark_popup,
        ["c"] = actions.change_popup,
        ["R"] = actions.change_revset,
        ["g"] = actions.refresh,
        ["q"] = actions.close,
        ["{"] = actions.prev_entry,
        ["}"] = actions.next_entry,
        ["y"] = actions.yank,
        ["?"] = actions.help_popup,
      },
    },
    render = function()
      return ui.render(instance.graph_lines, instance.revset)
    end,
    after = function(buf)
      -- Move cursor to first commit line
      local item_index = buf.ui.item_index
      if item_index and item_index[1] then
        buf:move_cursor(item_index[1].first)
      end
    end,
  }
end

function M:refresh()
  if not self.buffer then
    return
  end

  if self._refreshing then
    return
  end

  if self._debounce_timer then
    self._debounce_timer:stop()
    self._debounce_timer:close()
    self._debounce_timer = nil
  end

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

  local view = self.buffer:save_view()
  local cursor_line = self.buffer:cursor_line()

  log.get_graph_log_async(self.revset, { limit = 50 }, function(graph_lines)
    if not self.buffer then
      self._refreshing = false
      return
    end

    self.graph_lines = graph_lines
    self.buffer.ui:render(unpack(ui.render(self.graph_lines, self.revset)))
    self.buffer:restore_view(view, cursor_line)
    self._refreshing = false
  end)
end

---@param revset string|nil
function M:set_revset(revset)
  self.revset = revset
  self:refresh()
end

function M:close()
  if self._debounce_timer then
    self._debounce_timer:stop()
    self._debounce_timer:close()
    self._debounce_timer = nil
  end

  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
end

return M
