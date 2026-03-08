local M = {}

---@param message string
---@param level? integer
function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Maju" })
end

function M.info(message)
  M.notify(message, vim.log.levels.INFO)
end

function M.warn(message)
  M.notify(message, vim.log.levels.WARN)
end

function M.error(message)
  M.notify(message, vim.log.levels.ERROR)
end

return M
