---@class ProcessResult
---@field code integer
---@field stdout string[]
---@field stderr string[]

---@class Process
---@field cmd string[]
---@field cwd string|nil
---@field input string|nil
---@field env table|nil
local Process = {}
Process.__index = Process

---@param cmd string[]
---@param opts? {cwd?: string, input?: string, env?: table}
---@return Process
function Process.new(cmd, opts)
  opts = opts or {}
  return setmetatable({
    cmd = cmd,
    cwd = opts.cwd,
    input = opts.input,
    env = opts.env,
  }, Process)
end

---@return ProcessResult
function Process:wait()
  local sys_opts = {
    text = true,
    cwd = self.cwd,
    stdin = self.input,
    env = self.env,
  }

  local result = vim.system(self.cmd, sys_opts):wait()

  local stdout = {}
  if result.stdout and result.stdout ~= "" then
    stdout = vim.split(result.stdout, "\n", { trimempty = true })
  end

  local stderr = {}
  if result.stderr and result.stderr ~= "" then
    stderr = vim.split(result.stderr, "\n", { trimempty = true })
  end

  return {
    code = result.code,
    stdout = stdout,
    stderr = stderr,
  }
end

---@param callback fun(result: ProcessResult)
function Process:start(callback)
  local sys_opts = {
    text = true,
    cwd = self.cwd,
    stdin = self.input,
    env = self.env,
  }

  vim.system(self.cmd, sys_opts, function(result)
    local stdout = {}
    if result.stdout and result.stdout ~= "" then
      stdout = vim.split(result.stdout, "\n", { trimempty = true })
    end

    local stderr = {}
    if result.stderr and result.stderr ~= "" then
      stderr = vim.split(result.stderr, "\n", { trimempty = true })
    end

    vim.schedule(function()
      callback({
        code = result.code,
        stdout = stdout,
        stderr = stderr,
      })
    end)
  end)
end

return Process
