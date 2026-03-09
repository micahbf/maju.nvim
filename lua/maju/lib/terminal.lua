local Buffer = require("maju.lib.buffer")

local M = {}

---@param cmd_args string[]
---@param opts? {cwd?: string, on_exit?: fun()}
function M.run(cmd_args, opts)
  opts = opts or {}

  local buf = Buffer.create {
    name = "MajuTerminal",
    filetype = "MajuTerminal",
    kind = "floating_console",
    mappings = {
      n = {},
    },
    render = function()
      return {}, {}
    end,
  }

  vim.fn.termopen(cmd_args, {
    cwd = opts.cwd or require("maju.lib.jj.cli")._root,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if buf and buf:is_valid() then
          buf:close()
        end
        if opts.on_exit then
          opts.on_exit()
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

return M
