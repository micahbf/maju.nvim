local jj = require("maju.lib.jj.cli")
local notification = require("maju.lib.notification")

local M = {}

local function get_option_value(popup, cli_name)
  for _, arg in pairs(popup.state.args) do
    if arg.type == "option" and arg.cli == cli_name then
      return (arg.value and arg.value ~= "") and arg.value or nil
    end
  end
end

local function show_in_float(lines, title, filetype)
  if #lines == 0 then
    notification.info("No changes")
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  if filetype then
    vim.bo[buf].filetype = filetype
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = "rounded",
    style = "minimal",
    title = title,
  })

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "<esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

function M.view_diff(popup)
  local rev = get_option_value(popup, "revision") or "@"

  local result = jj.diff.git_format.revision(rev).call({ ignore_error = true })
  if result.code ~= 0 then
    notification.error("Diff failed: " .. table.concat(result.stderr, "\n"))
    return
  end

  show_in_float(result.stdout, " Diff: " .. rev .. " ", "diff")
end

function M.show_stat(popup)
  local rev = get_option_value(popup, "revision") or "@"

  local result = jj.diff.stat.revision(rev).call({ ignore_error = true })
  if result.code ~= 0 then
    notification.error("Stat failed: " .. table.concat(result.stderr, "\n"))
    return
  end

  show_in_float(result.stdout, " Stat: " .. rev .. " ")
end

return M
