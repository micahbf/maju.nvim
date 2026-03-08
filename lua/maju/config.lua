---@class MajuConfig
---@field use_per_project_settings boolean
---@field remember_settings boolean
---@field kind string
---@field disable_line_numbers boolean
---@field disable_relative_line_numbers boolean
---@field ignored_settings string[]
---@field highlight table
---@field mappings table
local M = {}

---@type MajuConfig
local default_config = {
  use_per_project_settings = true,
  remember_settings = true,
  kind = "auto",
  disable_line_numbers = true,
  disable_relative_line_numbers = true,
  ignored_settings = {},
  highlight = {},
  mappings = {},
}

---@type MajuConfig
M.values = vim.deepcopy(default_config)

---@param user_config? table
function M.setup(user_config)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_config or {})
end

return M
