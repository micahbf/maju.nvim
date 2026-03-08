local M = {}

---@param user_config? table
function M.setup(user_config)
  require("maju.config").setup(user_config)
  require("maju.lib.hl").setup()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("Maju-Highlights", { clear = true }),
    callback = function()
      require("maju.lib.hl").setup()
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("Maju-BufferReload", { clear = true }),
    pattern = "MajuStatusRefreshed",
    callback = function()
      vim.cmd("checktime")
    end,
  })
end

---@param kind? string
function M.open(kind)
  if vim.fn.executable("jj") ~= 1 then
    vim.notify("jj not found on PATH", vim.log.levels.ERROR)
    return
  end

  local config = require("maju.config")

  local root = M.find_root()
  if not root then
    vim.notify("Not in a jj repository", vim.log.levels.ERROR)
    return
  end

  require("maju.buffers.status").open(root, kind or config.values.kind)
end

---@return string|nil
function M.find_root()
  local result = vim.system({ "jj", "root" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout)
end

return M
