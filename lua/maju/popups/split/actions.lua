local split = require("maju.lib.jj.split")
local change = require("maju.lib.jj.change")
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

function M.split_interactive(popup)
  local rev = get_option_value(popup, "revision") or "@"

  if change.is_immutable(rev) then
    notification.warn("Cannot split: revision is immutable")
    return
  end

  local cmd = split.build_interactive_cmd({ revision = rev })
  terminal.run(cmd, {
    on_exit = function()
      refresh_status()
    end,
  })
end

function M.split_by_files(popup)
  local rev = get_option_value(popup, "revision") or "@"

  if change.is_immutable(rev) then
    notification.warn("Cannot split: revision is immutable")
    return
  end

  local files = split.get_files(rev)
  if #files == 0 then
    notification.info("No files to split")
    return
  end

  vim.ui.select(files, {
    prompt = "Select files for first change (multi-select not supported, pick one at a time)",
  }, function(file)
    if not file then
      return
    end

    local result = split.split_by_files(rev, { file })
    if result.success then
      notification.info("Split complete")
      refresh_status()
    else
      notification.error("Split failed: " .. (result.error or "unknown error"))
    end
  end)
end

return M
