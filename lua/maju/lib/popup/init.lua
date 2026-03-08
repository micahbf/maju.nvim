local PopupBuilder = require("maju.lib.popup.builder")
local util = require("maju.lib.util")
local state = require("maju.lib.state")
local input = require("maju.lib.input")
local notification = require("maju.lib.notification")

local build_reverse_lookup = util.build_reverse_lookup
local filter_map = util.filter_map

local ui = require("maju.lib.popup.ui")

---@class PopupData
---@field state PopupState
---@field buffer Buffer|nil
local M = {}

---@return PopupBuilder
function M.builder()
  return PopupBuilder.new(M.new)
end

---@param popup_state PopupState
---@return PopupData
function M.new(popup_state)
  local instance = {
    state = popup_state,
    buffer = nil,
  }
  setmetatable(instance, { __index = M })
  return instance
end

---@return string[]
function M:get_arguments()
  local flags = {}
  for _, arg in pairs(self.state.args) do
    if arg.type == "switch" and arg.enabled and not arg.internal then
      table.insert(flags, arg.cli_prefix .. arg.cli .. arg.cli_suffix)
    end
    if arg.type == "option" and arg.cli ~= "" and (arg.value and #arg.value ~= 0) and not arg.internal then
      table.insert(flags, arg.cli_prefix .. arg.cli .. "=" .. arg.value)
    end
  end
  return flags
end

---@param key string
---@return any|nil
function M:get_env(key)
  if not self.state.env then
    return nil
  end
  return self.state.env[key]
end

---@return table
function M:get_internal_arguments()
  local args = {}
  for _, arg in pairs(self.state.args) do
    if arg.type == "switch" and arg.enabled and arg.internal then
      args[arg.cli] = true
    end
  end
  return args
end

---@return string
function M:to_cli()
  return table.concat(self:get_arguments(), " ")
end

function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
end

---@param switch table
function M:toggle_switch(switch)
  if switch.options then
    local options = build_reverse_lookup(filter_map(switch.options, function(option)
      if option.condition and not option.condition() then
        return
      end
      return option.value
    end))

    local index = options[switch.cli or ""]
    switch.cli = options[(index + 1)] or options[1]
    switch.value = switch.cli
    switch.enabled = switch.cli ~= ""

    if switch.persisted ~= false then
      state.set({ self.state.name, switch.cli_suffix }, switch.cli)
    end
    return
  end

  switch.enabled = not switch.enabled

  if switch.user_input then
    if switch.enabled then
      local value = input.get_user_input(switch.cli_prefix .. switch.cli_base, { separator = "" })
      if value then
        switch.cli = switch.cli_base .. value
      end
    else
      switch.cli = switch.cli_base
    end
  end

  if switch.persisted ~= false then
    state.set({ self.state.name, switch.cli }, switch.enabled)
  end

  -- Disable incompatible switches/options
  if switch.enabled and #switch.incompatible > 0 then
    for _, var in ipairs(self.state.args) do
      if switch.incompatible[var.cli] then
        if var.type == "switch" then
          self:disable_switch(var)
        elseif var.type == "option" then
          self:disable_option(var)
        end
      end
    end
  end

  -- Disable dependent switches/options when this is turned off
  if not switch.enabled and #switch.dependent > 0 then
    for _, var in ipairs(self.state.args) do
      if switch.dependent[var.cli] then
        if var.type == "switch" then
          self:disable_switch(var)
        elseif var.type == "option" then
          self:disable_option(var)
        end
      end
    end
  end
end

---@param option table
---@param value? string
function M:set_option(option, value)
  if option.value and option.value ~= "" then
    option.value = ""
  elseif value then
    option.value = value
  elseif option.choices then
    vim.ui.select(option.choices, {
      prompt = option.description,
    }, function(choice)
      if choice then
        option.value = choice
      end
    end)
  elseif option.fn then
    option.value = option.fn(self, option)
  else
    option.value = input.get_user_input(option.cli, {
      separator = "=",
      default = option.value,
      cancel = option.value,
    })
  end

  state.set({ self.state.name, option.cli }, option.value)

  -- Disable incompatible
  if option.value and option.value ~= "" and #option.incompatible > 0 then
    for _, var in ipairs(self.state.args) do
      if option.incompatible[var.cli] then
        if var.type == "switch" then
          self:disable_switch(var)
        elseif var.type == "option" then
          self:disable_option(var)
        end
      end
    end
  end
end

function M:disable_switch(switch)
  if switch.enabled then
    self:toggle_switch(switch)
  end
end

function M:disable_option(option)
  if option.value and option.value ~= "" then
    self:set_option(option, "")
  end
end

function M:mappings()
  local mappings = {
    n = {
      ["q"] = function()
        self:close()
      end,
      ["<esc>"] = function()
        self:close()
      end,
      ["<tab>"] = function()
        local component = self.buffer.ui:get_interactive_component_under_cursor()
        if not component then
          return
        end

        if component.options.tag == "Switch" then
          self:toggle_switch(component.options.value)
        elseif component.options.tag == "Option" then
          self:set_option(component.options.value)
        end

        self:refresh()
      end,
    },
  }

  local arg_prefixes = {}
  for _, arg in pairs(self.state.args) do
    if arg.id then
      arg_prefixes[arg.key_prefix] = true
      mappings.n[arg.id] = function()
        if arg.type == "switch" then
          self:toggle_switch(arg)
        elseif arg.type == "option" then
          self:set_option(arg)
        end
        self:refresh()
      end
    end
  end

  for prefix, _ in pairs(arg_prefixes) do
    mappings.n[prefix] = function()
      local c = vim.fn.getcharstr()
      if mappings.n[prefix .. c] then
        mappings.n[prefix .. c]()
      end
    end
  end

  for _, group in pairs(self.state.actions) do
    for _, action in pairs(group) do
      if action.heading then
        -- nothing
      elseif action.callback then
        for _, key in ipairs(action.keys) do
          mappings.n[key] = function()
            if not action.persist_popup then
              self:close()
            end

            action.callback(self)
          end
        end
      else
        for _, key in ipairs(action.keys) do
          mappings.n[key] = function()
            notification.warn(action.description .. " has not been implemented yet")
          end
        end
      end
    end
  end

  return mappings
end

function M:refresh()
  if self.buffer then
    self.buffer.ui:render(unpack(ui.Popup(self.state)))
  end
end

---@return boolean
function M.is_open()
  return (M.instance and M.instance.buffer and M.instance.buffer:is_visible()) == true
end

function M:show()
  if M.is_open() then
    M.instance:close()
  end

  M.instance = self

  local Buffer = require("maju.lib.buffer")
  self.buffer = Buffer.create {
    name = self.state.name,
    filetype = "MajuPopup",
    kind = "popup",
    mappings = self:mappings(),
    status_column = " ",
    autocmds = {
      ["WinLeave"] = function()
        pcall(self.close, self)
      end,
    },
    after = function(buf)
      buf:set_window_option("cursorline", false)
      buf:set_window_option("list", false)

      local height = vim.fn.line("$") + 1
      vim.cmd.resize(height)

      vim.schedule(function()
        if buf:is_focused() then
          vim.cmd.resize(height)
          buf:set_window_option("winfixheight", true)
        end
      end)
    end,
    render = function()
      return ui.Popup(self.state)
    end,
  }
end

return M
