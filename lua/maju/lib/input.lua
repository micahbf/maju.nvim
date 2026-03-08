local M = {}

---@param prompt string
---@param opts? {default?: string, separator?: string, cancel?: string, completion?: string}
---@return string|nil
function M.get_user_input(prompt, opts)
  opts = opts or {}
  local sep = opts.separator or ": "

  local ok, result = pcall(vim.fn.input, {
    prompt = prompt .. sep,
    default = opts.default or "",
    completion = opts.completion,
    cancelreturn = vim.NIL,
  })

  if not ok or result == vim.NIL then
    return opts.cancel
  end

  return result
end

---@param prompt string
---@return boolean
function M.get_confirmation(prompt)
  local choice = vim.fn.confirm(prompt, "&Yes\n&No", 2)
  return choice == 1
end

---@param prompt string
---@param choices string[]
---@return string|nil
function M.get_choice(prompt, choices)
  local choice_str = table.concat(
    vim.tbl_map(function(c)
      return "&" .. c
    end, choices),
    "\n"
  )

  local idx = vim.fn.confirm(prompt, choice_str, 0)
  if idx == 0 then
    return nil
  end
  return choices[idx]
end

return M
