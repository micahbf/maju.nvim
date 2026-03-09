local Buffer = require("maju.lib.buffer")
local describe = require("maju.lib.jj.describe")
local notification = require("maju.lib.notification")

local M = {}

M.instance = nil

---@param root string
---@param revision string
---@param opts? {on_complete?: fun()}
function M.open(root, revision, opts)
  opts = opts or {}

  if M.instance and M.instance.buffer and M.instance.buffer:is_visible() then
    M.instance.buffer:focus()
    return
  end

  local current_desc = describe.get_description(revision)
  local diff_summary = describe.get_diff_summary(revision)

  -- Build initial buffer content
  local lines = {}

  -- Add existing description lines
  if current_desc ~= "" then
    for line in (current_desc .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "")
  end

  -- Add separator and comment block
  table.insert(lines, "")
  table.insert(lines, "JJ: Lines starting with 'JJ:' will be removed.")
  table.insert(lines, "JJ: An empty description aborts the operation.")
  table.insert(lines, "JJ: ---")

  if #diff_summary > 0 then
    table.insert(lines, "JJ: Changes:")
    for _, summary_line in ipairs(diff_summary) do
      table.insert(lines, "JJ:   " .. summary_line)
    end
  end

  local instance = {
    buffer = nil,
    root = root,
    revision = revision,
    on_complete = opts.on_complete,
  }

  M.instance = instance

  local buf_handle = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf_handle, "MajuDescribe")
  vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, lines)

  -- Open in a split below
  local win = vim.api.nvim_open_win(buf_handle, true, { split = "below" })
  vim.api.nvim_win_set_height(win, math.min(#lines + 2, math.floor(vim.o.lines * 0.3)))

  -- Buffer options
  vim.bo[buf_handle].buftype = "acwrite"
  vim.bo[buf_handle].bufhidden = "wipe"
  vim.bo[buf_handle].filetype = "MajuDescribe"
  vim.bo[buf_handle].modifiable = true

  -- Window options
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].spell = true
  vim.wo[win].wrap = true

  -- Add comment highlighting
  local ns = vim.api.nvim_create_namespace("maju-describe")
  for i, line in ipairs(lines) do
    if line:match("^JJ:") then
      vim.api.nvim_buf_set_extmark(buf_handle, ns, i - 1, 0, {
        line_hl_group = "MajuDescribeComment",
      })
    end
  end

  -- Place cursor at end of first non-empty line or line 1
  vim.api.nvim_win_set_cursor(win, { 1, #lines[1] })

  -- BufWriteCmd: intercept :w to save description
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf_handle,
    callback = function()
      local buf_lines = vim.api.nvim_buf_get_lines(buf_handle, 0, -1, false)

      -- Strip JJ: comment lines
      local message_lines = {}
      for _, line in ipairs(buf_lines) do
        if not line:match("^JJ:") then
          table.insert(message_lines, line)
        end
      end

      -- Trim trailing blank lines
      while #message_lines > 0 and message_lines[#message_lines] == "" do
        table.remove(message_lines)
      end

      local message = table.concat(message_lines, "\n")

      if message == "" then
        notification.warn("Empty description — aborted")
        return
      end

      local result = describe.set_description(revision, message)
      if result.success then
        notification.info("Description updated")
        vim.bo[buf_handle].modified = false
        -- Close the buffer
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf_handle) then
            local wins = vim.fn.win_findbuf(buf_handle)
            for _, w in ipairs(wins) do
              pcall(vim.api.nvim_win_close, w, true)
            end
          end
          M.instance = nil
          if instance.on_complete then
            instance.on_complete()
          end
        end)
      else
        notification.error("Describe failed: " .. (result.error or "unknown"))
      end
    end,
  })

  -- q to cancel
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_buf_is_valid(buf_handle) then
      local wins = vim.fn.win_findbuf(buf_handle)
      for _, w in ipairs(wins) do
        pcall(vim.api.nvim_win_close, w, true)
      end
    end
    M.instance = nil
  end, { buffer = buf_handle, nowait = true })

  -- Cleanup on detach
  vim.api.nvim_buf_attach(buf_handle, false, {
    on_detach = function()
      if M.instance == instance then
        M.instance = nil
      end
    end,
  })
end

return M
