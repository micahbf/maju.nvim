local state_mod = require("maju.lib.state")
local util = require("maju.lib.util")
local notification = require("maju.lib.notification")

---@class PopupBuilder
---@field state PopupState
---@field builder_fn fun(state: PopupState): PopupData
local M = {}

---@class PopupState
---@field name string
---@field args table[]
---@field config table[]
---@field actions table[][]
---@field env table
---@field keys table<string, boolean>

---@param builder_fn fun(state: PopupState): PopupData
---@return PopupBuilder
function M.new(builder_fn)
  local instance = {
    state = {
      name = nil,
      args = {},
      config = {},
      actions = { {} },
      env = {},
      keys = {},
    },
    builder_fn = builder_fn,
  }
  setmetatable(instance, { __index = M })
  return instance
end

---@param name string
---@return self
function M:name(name)
  self.state.name = name
  return self
end

---@param env table
---@return self
function M:env(env)
  self.state.env = env or {}
  return self
end

---@param heading string?
---@return self
function M:new_action_group(heading)
  table.insert(self.state.actions, { { heading = heading or "" } })
  return self
end

---@param heading string
---@return self
function M:group_heading(heading)
  table.insert(self.state.actions[#self.state.actions], { heading = heading })
  return self
end

---@param key string
---@param cli string
---@param description string
---@param opts? table
---@return self
function M:switch(key, cli, description, opts)
  opts = opts or {}

  local key_prefix = opts.key_prefix or "-"
  local cli_prefix = opts.cli_prefix or "--"
  local cli_suffix = opts.cli_suffix or ""
  local persisted = opts.persisted ~= false
  local incompatible = opts.incompatible or {}
  local dependent = opts.dependent or {}

  local enabled
  if opts.options then
    enabled = state_mod.get({ self.state.name, cli_suffix }, "") ~= ""
  else
    enabled = state_mod.get({ self.state.name, cli }, opts.enabled or false)
  end

  local value = cli
  if opts.enabled and opts.value then
    value = cli .. opts.value
  end

  table.insert(self.state.args, {
    type = "switch",
    id = key_prefix .. key,
    key = key,
    key_prefix = key_prefix,
    cli = value,
    value = value,
    cli_base = cli,
    description = description,
    enabled = enabled,
    internal = opts.internal or false,
    cli_prefix = cli_prefix,
    cli_suffix = cli_suffix,
    persisted = persisted,
    user_input = opts.user_input,
    options = opts.options,
    incompatible = util.build_reverse_lookup(incompatible),
    dependent = util.build_reverse_lookup(dependent),
  })

  return self
end

---@param key string
---@param cli string
---@param value string
---@param description string
---@param opts? table
---@return self
function M:option(key, cli, value, description, opts)
  opts = opts or {}

  local key_prefix = opts.key_prefix or "="
  local cli_prefix = opts.cli_prefix or "--"
  local separator = opts.separator or "="
  local dependent = opts.dependent or {}
  local incompatible = opts.incompatible or {}

  if opts.setup then
    opts.setup(self)
  end

  table.insert(self.state.args, {
    type = "option",
    id = key_prefix .. key,
    key = key,
    key_prefix = key_prefix,
    cli = cli,
    value = state_mod.get({ self.state.name, cli }, value),
    description = description,
    cli_prefix = cli_prefix,
    choices = opts.choices,
    default = opts.default,
    separator = separator,
    dependent = util.build_reverse_lookup(dependent),
    incompatible = util.build_reverse_lookup(incompatible),
    fn = opts.fn,
  })

  return self
end

---@param heading string
---@return self
function M:arg_heading(heading)
  table.insert(self.state.args, { type = "heading", heading = heading })
  return self
end

function M:spacer()
  table.insert(self.state.actions[#self.state.actions], {
    keys = "",
    description = "",
    heading = "",
  })
  return self
end

---@param keys string|string[]
---@param description string
---@param callback? fun(popup: PopupData)
---@param opts? table
---@return self
function M:action(keys, description, callback, opts)
  opts = opts or {}

  if type(keys) == "string" then
    keys = { keys }
  end

  for _, key in pairs(keys) do
    if self.state.keys[key] then
      notification.error(string.format("[POPUP] Duplicate key mapping %q", key))
      return self
    end
    self.state.keys[key] = true
  end

  table.insert(self.state.actions[#self.state.actions], {
    keys = keys,
    description = description,
    callback = callback,
    persist_popup = opts.persist_popup or false,
  })

  return self
end

---@param cond boolean
---@param keys string|string[]
---@param description string
---@param callback? fun(popup: PopupData)
---@param opts? table
---@return self
function M:action_if(cond, keys, description, callback, opts)
  if cond then
    return self:action(keys, description, callback, opts)
  end
  return self
end

---@return PopupData
function M:build()
  if self.state.name == nil then
    error("A popup needs to have a name!")
  end
  return self.builder_fn(self.state)
end

return M
