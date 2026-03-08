---@class MajuState
---@field loaded boolean
---@field _enabled boolean
---@field state table
---@field path string
local M = {}

M.loaded = false

---@return string
function M.filepath()
  local state_path = vim.fn.stdpath("state") .. "/maju"
  local filename = "state"

  local config = require("maju.config")
  if config.values.use_per_project_settings then
    local cwd = vim.uv.cwd() or ""
    filename = cwd:gsub("^(%a):", "/%1"):gsub("/", "%%")
  end

  return state_path .. "/" .. filename
end

function M.setup()
  if M.loaded then
    return
  end

  local config = require("maju.config")
  M.path = M.filepath()
  M._enabled = config.values.remember_settings
  M.state = M.read()
  M.loaded = true
end

---@return boolean
function M.enabled()
  return M.loaded and M._enabled
end

---@return table
function M.read()
  if not M.enabled() then
    return {}
  end

  local path = M.path
  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  if vim.fn.filereadable(path) == 0 then
    local f = io.open(path, "w")
    if f then
      f:write(vim.mpack.encode {})
      f:close()
    end
  end

  local f = io.open(path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and content ~= "" then
      local ok, decoded = pcall(vim.mpack.decode, content)
      if ok then
        return decoded
      end
    end
  end

  return {}
end

function M.write()
  if not M.enabled() then
    return
  end

  local f = io.open(M.path, "w")
  if f then
    f:write(vim.mpack.encode(M.state))
    f:close()
  end
end

---@param key_table table
---@return string
local function gen_key(key_table)
  return table.concat(key_table, "--")
end

---@param key string[]
---@param value any
function M.set(key, value)
  if not M.enabled() then
    return
  end

  local config = require("maju.config")
  local cache_key = gen_key(key)
  if not vim.tbl_contains(config.values.ignored_settings, cache_key) then
    if value == "" then
      M.state[cache_key] = nil
    else
      M.state[cache_key] = value
    end
    M.write()
  end
end

---@param key table
---@param default any
---@return any
function M.get(key, default)
  if not M.enabled() then
    return default
  end

  local value = M.state[gen_key(key)]
  if value ~= nil then
    return value
  else
    return default
  end
end

function M._reset()
  local f = io.open(M.path, "w")
  if f then
    f:write(vim.mpack.encode {})
    f:close()
  end
  M.state = {}
end

return M
