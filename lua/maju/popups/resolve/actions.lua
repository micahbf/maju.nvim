local conflict = require("maju.lib.jj.conflict")
local repository = require("maju.lib.jj.repository")
local terminal = require("maju.lib.terminal")
local notification = require("maju.lib.notification")

local M = {}

local function refresh_status()
  local status_buf = require("maju.buffers.status")
  if status_buf.instance then
    status_buf.instance:refresh()
  end
end

local function get_option_value(popup, cli_name)
  for _, arg in pairs(popup.state.args) do
    if arg.type == "option" and arg.cli == cli_name then
      return (arg.value and arg.value ~= "") and arg.value or nil
    end
  end
end

function M.resolve(popup)
  local conflicts = repository.state.conflicts
  if not conflicts or #conflicts == 0 then
    notification.info("No conflicts to resolve")
    return
  end

  local tool = get_option_value(popup, "tool")

  vim.ui.select(conflicts, { prompt = "Select file to resolve" }, function(file)
    if not file then
      return
    end

    local cmd = conflict.build_cmd({ tool = tool })
    table.insert(cmd, file)

    terminal.run(cmd, {
      on_exit = function()
        refresh_status()
      end,
    })
  end)
end

return M
