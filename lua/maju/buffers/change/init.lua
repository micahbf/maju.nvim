local Buffer = require("maju.lib.buffer")
local config = require("maju.config")
local ui = require("maju.buffers.change.ui")
local log = require("maju.lib.jj.log")
local status = require("maju.lib.jj.status")
local diff = require("maju.lib.jj.diff")
local describe_lib = require("maju.lib.jj.describe")
local notification = require("maju.lib.notification")

---@class ChangeBuffer
---@field buffer Buffer|nil
---@field root string
---@field change_id string
---@field entry DetailEntry|nil
---@field description string
---@field changes FileChange[]
---@field fold_state table|nil
local M = {}
M.__index = M

M.instance = nil

---@param root string
---@param change_id string
---@param kind? string
function M.open(root, change_id, kind)
  if M.instance and M.instance.buffer and M.instance.buffer:is_visible() then
    -- If viewing a different change, refresh
    if M.instance.change_id ~= change_id then
      M.instance.change_id = change_id
      M.instance:_load_and_render()
    else
      M.instance.buffer:focus()
    end
    return
  end

  local instance = setmetatable({
    root = root,
    buffer = nil,
    change_id = change_id,
    entry = nil,
    description = "",
    changes = {},
    fold_state = nil,
  }, M)

  M.instance = instance

  -- Fetch data synchronously for initial render
  instance.entry = log.get_detail(change_id)
  instance.description = describe_lib.get_description(change_id)
  instance.changes = status.get_parent_changes(change_id)

  -- Set up lazy diff loading on changes
  for _, file in ipairs(instance.changes) do
    diff.build_metatable(file, change_id)
  end

  local actions = require("maju.buffers.change.actions")

  instance.buffer = Buffer.create {
    name = "MajuChange:" .. change_id,
    filetype = "MajuChange",
    kind = kind or "floating",
    cwd = root,
    context_highlight = true,
    foldmarkers = true,
    disable_line_numbers = true,
    disable_relative_line_numbers = true,
    on_detach = function()
      if M.instance == instance then
        M.instance = nil
      end
    end,
    mappings = {
      n = {
        ["<tab>"] = actions.toggle,
        ["<cr>"] = actions.goto_file,
        ["e"] = actions.edit,
        ["D"] = actions.describe,
        ["d"] = actions.diff_popup,
        ["r"] = actions.rebase_popup,
        ["b"] = actions.bookmark_popup,
        ["g"] = actions.refresh,
        ["q"] = actions.close,
        ["{"] = actions.prev_section,
        ["}"] = actions.next_section,
        ["y"] = actions.yank,
      },
    },
    render = function()
      return ui.render(instance)
    end,
    after = function(buf)
      local first = buf.ui:first_section()
      if first then
        buf:move_cursor(first.first)
      end
    end,
  }
end

function M:_load_and_render()
  if not self.buffer then
    return
  end

  self.entry = log.get_detail(self.change_id)
  self.description = describe_lib.get_description(self.change_id)
  self.changes = status.get_parent_changes(self.change_id)

  for _, file in ipairs(self.changes) do
    require("maju.lib.jj.diff").build_metatable(file, self.change_id)
  end

  self.buffer.ui:render(unpack(ui.render(self)))
end

function M:refresh()
  if not self.buffer then
    return
  end

  local view = self.buffer:save_view()
  local cursor_line = self.buffer:cursor_line()

  self:_load_and_render()
  self.buffer:restore_view(view, cursor_line)
end

function M:close()
  if self.buffer then
    self.fold_state = self.buffer.ui:get_fold_state()
    self.buffer:close()
    self.buffer = nil
  end
end

return M
