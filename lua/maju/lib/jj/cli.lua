local Process = require("maju.lib.process")

local k_state = {}
local k_config = {}
local k_command = {}

---@class JjCommandSetup
---@field flags? table
---@field options? table
---@field aliases? table
---@field subcommands? table

local function config(setup)
  setup = setup or {}
  return {
    flags = setup.flags or {},
    options = setup.options or {},
    aliases = setup.aliases or {},
    subcommands = setup.subcommands or {},
  }
end

local configurations = {
  status = config {},

  diff = config {
    flags = {
      git_format = "--git",
      stat = "--stat",
      summary = "--summary",
      name_only = "--name-only",
    },
    options = {
      revision = "-r",
      from = "--from",
      to = "--to",
    },
  },

  log = config {
    flags = {
      no_graph = "--no-graph",
      reversed = "--reversed",
    },
    options = {
      revisions = "-r",
      template = "-T",
      limit = "-n",
    },
  },

  show = config {
    flags = {
      git_format = "--git",
      stat = "--stat",
      summary = "--summary",
    },
    options = {
      revision = "-r",
      template = "-T",
    },
  },

  new = config {
    flags = {
      no_edit = "--no-edit",
      insert_before = "-B",
      insert_after = "-A",
    },
    options = {
      message = "-m",
    },
  },

  edit = config {
    options = {
      revision = "-r",
    },
  },

  describe = config {
    flags = {
      reset_author = "--reset-author",
    },
    options = {
      revision = "-r",
      message = "-m",
    },
  },

  abandon = config {
    options = {
      revision = "-r",
    },
  },

  duplicate = config {},

  revert = config {},

  squash = config {
    flags = {
      interactive = "-i",
    },
    options = {
      revision = "-r",
      from = "--from",
      into = "--into",
      tool = "--tool",
    },
  },

  unsquash = config {
    flags = {
      interactive = "-i",
    },
    options = {
      revision = "-r",
    },
  },

  split = config {
    flags = {
      interactive = "-i",
    },
    options = {
      revision = "-r",
      tool = "--tool",
    },
  },

  restore = config {
    options = {
      from = "--from",
      to = "--to",
      revision = "-r",
      changes_in = "--changes-in",
    },
  },

  rebase = config {
    options = {
      source = "-s",
      revision = "-r",
      destination = "-d",
      branch = "-b",
      insert_after = "-A",
      insert_before = "-B",
    },
  },

  bookmark = config {
    subcommands = {
      create = config {
        options = { revision = "-r" },
      },
      delete = config {},
      forget = config {},
      list = config {
        flags = {
          all_remotes = "--all-remotes",
        },
        options = {
          template = "-T",
        },
      },
      move = config {
        flags = {
          allow_backwards = "-B",
        },
        options = {
          from = "--from",
          to = "--to",
          revision = "-r",
        },
      },
      rename = config {},
      set = config {
        options = { revision = "-r" },
      },
      track = config {},
      untrack = config {},
    },
  },

  git = config {
    subcommands = {
      push = config {
        flags = {
          all = "--all",
          deleted = "--deleted",
          dry_run = "--dry-run",
        },
        options = {
          remote = "--remote",
          bookmark = "-b",
          change = "--change",
          revisions = "-r",
        },
      },
      fetch = config {
        flags = {
          all_remotes = "--all-remotes",
        },
        options = {
          remote = "--remote",
          branch = "--branch",
        },
      },
      clone = config {},
      init = config {},
    },
  },

  op = config {
    subcommands = {
      log = config {
        flags = {
          no_graph = "--no-graph",
        },
        options = {
          template = "-T",
          limit = "-n",
        },
      },
      undo = config {},
      restore = config {},
    },
  },

  file = config {
    subcommands = {
      show = config {
        options = {
          revision = "-r",
        },
      },
    },
  },

  config = config {
    subcommands = {
      get = config {},
      set = config {},
      list = config {
        options = {
          template = "-T",
        },
      },
    },
  },

  resolve = config {
    flags = {
      list = "--list",
    },
    options = {
      revision = "-r",
      tool = "--tool",
    },
  },
}

local history = {}

local mt_builder = {
  __index = function(tbl, action)
    if action == "args" or action == "arguments" then
      return function(...)
        for _, v in ipairs { ... } do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == "arg_list" then
      return function(args)
        for _, v in ipairs(args) do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == "files" or action == "paths" then
      return function(...)
        for _, v in ipairs { ... } do
          table.insert(tbl[k_state].files, v)
        end
        return tbl
      end
    end

    if action == "input" or action == "stdin" then
      return function(value)
        tbl[k_state].input = value
        return tbl
      end
    end

    if action == "env" then
      return function(cfg)
        for k, v in pairs(cfg) do
          tbl[k_state].env[k] = v
        end
        return tbl
      end
    end

    -- Check flags
    if tbl[k_config].flags[action] then
      table.insert(tbl[k_state].options, tbl[k_config].flags[action])
      return tbl
    end

    -- Check options (takes a value)
    if tbl[k_config].options[action] then
      return function(value)
        if value and value ~= "" then
          table.insert(tbl[k_state].options, tbl[k_config].options[action])
          table.insert(tbl[k_state].options, value)
        end
        return tbl
      end
    end

    -- Check subcommands
    if tbl[k_config].subcommands and tbl[k_config].subcommands[action] then
      table.insert(tbl[k_state].subcommands, action)
      -- Merge subcommand config into current config
      local sub_config = tbl[k_config].subcommands[action]
      tbl[k_config] = {
        flags = vim.tbl_extend("force", {}, sub_config.flags or {}),
        options = vim.tbl_extend("force", {}, sub_config.options or {}),
        aliases = vim.tbl_extend("force", {}, sub_config.aliases or {}),
        subcommands = sub_config.subcommands or {},
      }
      return tbl
    end

    -- Check aliases
    if tbl[k_config].aliases[action] then
      return tbl[k_config].aliases[action](tbl, tbl[k_state])
    end

    error("unknown field: " .. action)
  end,

  __tostring = function(tbl)
    local parts = { "jj", tbl[k_command] }
    for _, sub in ipairs(tbl[k_state].subcommands) do
      table.insert(parts, sub)
    end
    for _, opt in ipairs(tbl[k_state].options) do
      table.insert(parts, opt)
    end
    for _, arg in ipairs(tbl[k_state].arguments) do
      table.insert(parts, arg)
    end
    if #tbl[k_state].files > 0 then
      table.insert(parts, "--")
      for _, f in ipairs(tbl[k_state].files) do
        table.insert(parts, f)
      end
    end
    return table.concat(parts, " ")
  end,
}

---@param root? string
local function build_cmd(state, command, root)
  local cmd = { "jj", "--no-pager", "--color", "never" }

  table.insert(cmd, command)
  for _, sub in ipairs(state.subcommands) do
    table.insert(cmd, sub)
  end
  for _, o in ipairs(state.options) do
    table.insert(cmd, o)
  end
  for _, arg in ipairs(state.arguments) do
    if arg ~= "" then
      table.insert(cmd, arg)
    end
  end
  if #state.files > 0 then
    table.insert(cmd, "--")
    for _, f in ipairs(state.files) do
      table.insert(cmd, f)
    end
  end

  return cmd, root
end

local function new_builder(command)
  local configuration = configurations[command]
  if not configuration then
    error("Command not found: " .. command)
  end

  local state = {
    options = {},
    arguments = {},
    subcommands = {},
    files = {},
    input = nil,
    env = {},
  }

  local function call(opts)
    opts = opts or {}
    local root = opts.cwd or require("maju.lib.jj.cli")._root
    local cmd, cwd = build_cmd(state, command, root)

    local process = Process.new(cmd, {
      cwd = cwd,
      input = state.input,
      env = next(state.env) and state.env or nil,
    })

    local result = process:wait()

    table.insert(history, {
      cmd = table.concat(cmd, " "),
      code = result.code,
      time = os.time(),
    })

    if result.code ~= 0 and not opts.ignore_error then
      if opts.on_error then
        opts.on_error(result)
      end
    end

    return result
  end

  local function call_async(callback, opts)
    opts = opts or {}
    local root = opts.cwd or require("maju.lib.jj.cli")._root
    local cmd, cwd = build_cmd(state, command, root)

    local process = Process.new(cmd, {
      cwd = cwd,
      input = state.input,
      env = next(state.env) and state.env or nil,
    })

    process:start(function(result)
      table.insert(history, {
        cmd = table.concat(cmd, " "),
        code = result.code,
        time = os.time(),
      })
      if callback then
        callback(result)
      end
    end)
  end

  return setmetatable({
    [k_state] = state,
    [k_config] = {
      flags = vim.tbl_extend("force", {}, configuration.flags),
      options = vim.tbl_extend("force", {}, configuration.options),
      aliases = vim.tbl_extend("force", {}, configuration.aliases),
      subcommands = configuration.subcommands or {},
    },
    [k_command] = command,
    call = call,
    call_async = call_async,
  }, mt_builder)
end

local meta = {
  __index = function(tbl, key)
    if key == "_root" or key == "history" then
      return rawget(tbl, key)
    end
    if configurations[key] then
      return new_builder(key)
    end
    error("unknown command: " .. key)
  end,
}

local cli = setmetatable({
  _root = nil,
  history = history,
}, meta)

return cli
