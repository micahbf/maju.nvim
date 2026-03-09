if vim.g.loaded_maju then
  return
end
vim.g.loaded_maju = true

vim.api.nvim_create_user_command("Maju", function(opts)
  require("maju").open(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  desc = "Open Maju status buffer",
})

vim.api.nvim_create_user_command("MajuLog", function(opts)
  if vim.fn.executable("jj") ~= 1 then
    vim.notify("jj not found on PATH", vim.log.levels.ERROR)
    return
  end

  local root = require("maju").find_root()
  if not root then
    vim.notify("Not in a jj repository", vim.log.levels.ERROR)
    return
  end

  require("maju.lib.jj.cli")._root = root
  local revset = opts.args ~= "" and opts.args or nil
  require("maju.buffers.log").open(root, nil, { revset = revset })
end, {
  nargs = "?",
  desc = "Open Maju log view",
})

vim.api.nvim_create_user_command("MajuDebug", function()
  require("maju.lib.hl").debug()
end, {
  desc = "Debug Maju highlight state",
})
