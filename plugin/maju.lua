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

vim.api.nvim_create_user_command("MajuDebug", function()
  require("maju.lib.hl").debug()
end, {
  desc = "Debug Maju highlight state",
})
