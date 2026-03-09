local Buffer = require("maju.lib.buffer")
local config = require("maju.config")
local ui = require("maju.buffers.oplog.ui")
local operation = require("maju.lib.jj.operation")
local notification = require("maju.lib.notification")

---@class OpLogBuffer
---@field buffer Buffer|nil
---@field root string
---@field entries OpLogEntry[]
local M = {}
M.__index = M

M.instance = nil

---@param root string
function M.open(root)
  if M.instance and M.instance.buffer and M.instance.buffer:is_visible() then
    M.instance.buffer:focus()
    return
  end

  local instance = setmetatable({
    root = root,
    buffer = nil,
    entries = {},
  }, M)

  M.instance = instance

  instance.entries = operation.get_op_log_structured({ limit = 50 })

  if #instance.entries == 0 then
    notification.info("No operations in log")
    M.instance = nil
    return
  end

  local actions = require("maju.buffers.oplog.actions")

  instance.buffer = Buffer.create {
    name = "MajuOpLog",
    filetype = "MajuOpLog",
    kind = "floating",
    disable_line_numbers = true,
    disable_relative_line_numbers = true,
    foldmarkers = false,
    on_detach = function()
      if M.instance == instance then
        M.instance = nil
      end
    end,
    mappings = {
      n = {
        ["<cr>"] = actions.restore,
        ["R"] = actions.restore,
        ["g"] = actions.refresh,
        ["q"] = actions.close,
        ["<esc>"] = actions.close,
        ["y"] = actions.yank,
        ["{"] = actions.prev_entry,
        ["}"] = actions.next_entry,
      },
    },
    render = function()
      return ui.render(instance.entries)
    end,
  }
end

function M:refresh()
  if not self.buffer then
    return
  end

  self.entries = operation.get_op_log_structured({ limit = 50 })
  self.buffer.ui:render(unpack(ui.render(self.entries)))
end

function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
end

return M
