local api = vim.api
local fn = vim.fn
local util = require("maju.lib.util")

local Ui = require("maju.lib.ui")
local config = require("maju.config")

-- Minimal signs table replacing neogit.lib.signs
local signs = {
  MajuOpenSection = "▾",
  MajuClosedSection = "▸",
  MajuOpenItem = "▾",
  MajuClosedItem = "▸",
  MajuOpenHunk = "▾",
  MajuClosedHunk = "▸",
  MajuBlank = " ",
}

local function signs_get(name)
  local sign = signs[name]
  if sign == "" then
    return " "
  else
    return sign or " "
  end
end

---@class Buffer
---@field handle number
---@field win_handle number
---@field header_win_handle number?
---@field namespaces table
---@field autocmd_group number
---@field ui Ui
---@field kind string
---@field name string
local Buffer = {
  kind = "split",
}
Buffer.__index = Buffer

---@param handle number
---@param win_handle number
---@return Buffer
function Buffer:new(handle, win_handle)
  local this = {
    autocmd_group = api.nvim_create_augroup("Maju-augroup-" .. handle, { clear = true }),
    handle = handle,
    win_handle = win_handle,
    border = nil,
    kind = nil,
    name = nil,
    namespaces = {
      default = api.nvim_create_namespace("maju-buffer-" .. handle),
    },
  }

  this.ui = Ui.new(this)

  setmetatable(this, self)

  return this
end

---@return number|nil
function Buffer:focus()
  local windows = fn.win_findbuf(self.handle)

  if not windows or not windows[1] then
    return nil
  end

  fn.win_gotoid(windows[1])
  return windows[1]
end

---@return boolean
function Buffer:is_focused()
  return api.nvim_win_get_buf(0) == self.handle
end

---@return number
function Buffer:get_changedtick()
  return api.nvim_buf_get_changedtick(self.handle)
end

function Buffer:lock()
  self:set_buffer_option("readonly", true)
  self:set_buffer_option("modifiable", false)
end

function Buffer:clear()
  api.nvim_buf_set_lines(self.handle, 0, -1, false, {})
end

---@param fn fun()
function Buffer:with_locked_viewport(fn)
  local view = self:save_view()
  self:call(fn)
  self:restore_view(view)
end

---@return table
function Buffer:save_view()
  local view = fn.winsaveview()
  return {
    topline = view.topline,
    leftcol = 0,
  }
end

---@param view table output of Buffer:save_view()
---@param cursor? number
function Buffer:restore_view(view, cursor)
  self:win_call(function()
    if cursor then
      view.lnum = math.min(fn.line("$"), cursor)
    end

    fn.winrestview(view)
  end)
end

function Buffer:write()
  self:win_exec("silent w!")
end

function Buffer:get_lines(first, last, strict)
  return api.nvim_buf_get_lines(self.handle, first, last, strict or false)
end

function Buffer:get_line(line)
  return fn.getbufline(self.handle, line)
end

function Buffer:get_current_line()
  return self:get_line(fn.getpos(".")[2])
end

function Buffer:set_lines(first, last, strict, lines)
  api.nvim_buf_set_lines(self.handle, first, last, strict, lines)
end

function Buffer:insert_line(line)
  local line_nr = fn.line(".") - 1
  api.nvim_buf_set_lines(self.handle, line_nr, line_nr, false, { line })
end

function Buffer:resize(length)
  api.nvim_buf_set_lines(self.handle, length, -1, false, {})
end

function Buffer:set_highlights(highlights)
  for _, highlight in ipairs(highlights) do
    self:add_highlight(unpack(highlight))
  end
end

function Buffer:set_extmarks(extmarks)
  for _, ext in ipairs(extmarks) do
    self:set_extmark(unpack(ext))
  end
end

function Buffer:set_line_highlights(highlights)
  for _, hl in ipairs(highlights) do
    self:add_line_highlight(unpack(hl))
  end
end

function Buffer:set_folds(folds)
  self:set_window_option("foldmethod", "manual")

  for _, fold in ipairs(folds) do
    self:create_fold(unpack(fold))
    self:set_fold_state(unpack(fold))
  end
end

function Buffer:set_text(first_line, last_line, first_col, last_col, lines)
  api.nvim_buf_set_text(self.handle, first_line, first_col, last_line, last_col, lines)
end

---@param line nil|integer|integer[]
function Buffer:move_cursor(line)
  if not line or not self:is_focused() then
    return
  end

  local position = { line, 0 }

  if type(line) == "table" then
    position = line
  end

  -- pcall used in case the line is out of bounds
  pcall(api.nvim_win_set_cursor, self.win_handle, position)
end

---@param line nil|number|number[]
function Buffer:move_top_line(line)
  if not line or not self:is_focused() then
    return
  end

  if vim.o.lines < fn.line("$") then
    return
  end

  local position = { line, 0 }

  if type(line) == "table" then
    position = line
  end

  -- pcall used in case the line is out of bounds
  pcall(vim.api.nvim_command, "normal! " .. position[1] .. "zt")
end

function Buffer:cursor_line()
  return api.nvim_win_get_cursor(0)[1]
end

function Buffer:close(force)
  if force == nil then
    force = false
  end

  if self.kind == "replace" then
    if self.old_cwd then
      api.nvim_set_current_dir(self.old_cwd)
      self.old_cwd = nil
    end

    api.nvim_buf_delete(self.handle, { force = force })
    return
  end

  if self.kind == "tab" then
    local ok, _ = pcall(vim.cmd, "tabclose")
    if not ok and #api.nvim_list_tabpages() == 1 then
      ok, _ = pcall(vim.cmd, "bd! " .. self.handle)
    end
    if not ok then
      vim.cmd("tab sb " .. self.handle)
      vim.cmd("tabclose #")
    end

    return
  end

  if api.nvim_buf_is_valid(self.handle) then
    local winnr = fn.bufwinnr(self.handle)
    if winnr ~= -1 then
      local winid = fn.win_getid(winnr)
      vim.schedule_wrap(util.safe_win_close)(winid, force)
    else
      vim.schedule_wrap(api.nvim_buf_delete)(self.handle, { force = force })
    end
  end
end

function Buffer:hide()
  if not self:focus() then
    return
  end

  if self.kind == "tab" then
    vim.cmd("silent! 1only")
    vim.cmd("try | tabn # | catch /.*/ | tabp | endtry")
  elseif self.kind == "replace" then
    if self.old_cwd then
      api.nvim_set_current_dir(self.old_cwd)
      self.old_cwd = nil
    end

    if self.old_buf and api.nvim_buf_is_loaded(self.old_buf) then
      api.nvim_set_current_buf(self.old_buf)
      self.old_buf = nil
    end
  else
    util.safe_win_close(0, true)
  end
end

function Buffer:is_visible()
  local buffer_in_window = #fn.win_findbuf(self.handle) > 0
  local window_in_tabpage = vim.tbl_contains(api.nvim_tabpage_list_wins(0), self.win_handle)

  return buffer_in_window and window_in_tabpage
end

---@return number
function Buffer:show()
  local windows = fn.win_findbuf(self.handle)

  -- Already visible
  if #windows > 0 then
    vim.api.nvim_set_current_win(windows[1])
    return windows[1]
  end

  if self.kind == "auto" then
    if vim.o.columns / 2 < 80 then
      self.kind = "split"
    else
      self.kind = "vsplit"
    end
  end

  ---@return integer window handle
  local function open()
    local win
    if self.kind == "replace" then
      self.old_buf = api.nvim_get_current_buf()
      self.old_cwd = vim.uv.cwd()
      api.nvim_set_current_buf(self.handle)
      win = api.nvim_get_current_win()
    elseif self.kind == "tab" then
      vim.cmd("tab sb " .. self.handle)
      win = api.nvim_get_current_win()
    elseif self.kind == "split" or self.kind == "split_below" then
      win = api.nvim_open_win(self.handle, true, { split = "below" })
    elseif self.kind == "split_above" then
      win = api.nvim_open_win(self.handle, true, { split = "above" })
    elseif self.kind == "split_above_all" then
      win = api.nvim_open_win(self.handle, true, { split = "above", win = -1 })
    elseif self.kind == "split_below_all" then
      win = api.nvim_open_win(self.handle, true, { split = "below", win = -1 })
    elseif self.kind == "vsplit" then
      win = api.nvim_open_win(self.handle, true, { split = "right", vertical = true })
    elseif self.kind == "vsplit_left" then
      win = api.nvim_open_win(self.handle, true, { split = "left", vertical = true })
    elseif self.kind == "floating" then
      -- Sensible defaults for floating window
      local float_width = 0.8
      local float_height = 0.8
      local vim_height = vim.o.lines
      local vim_width = vim.o.columns
      local width = math.floor(vim_width * float_width)
      local height = math.floor(vim_height * float_height)

      local content_window = api.nvim_open_win(self.handle, true, {
        width = width,
        height = height,
        relative = "editor",
        border = "rounded",
        style = "minimal",
        col = (vim_width - width) / 2,
        row = (vim_height - height) / 2,
        focusable = true,
      })

      api.nvim_win_set_cursor(content_window, { 1, 0 })
      win = content_window
    elseif self.kind == "floating_console" then
      local content_window = api.nvim_open_win(self.handle, true, {
        anchor = "SW",
        relative = "editor",
        width = vim.o.columns,
        height = math.floor(vim.o.lines * 0.3),
        col = 0,
        row = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0),
        style = "minimal",
        focusable = true,
        border = { "─", "─", "─", "", "", "", "", "" },
        title = " JJ Console ",
      })

      api.nvim_win_set_cursor(content_window, { 1, 0 })
      win = content_window
    elseif self.kind == "popup" then
      local content_window = api.nvim_open_win(self.handle, true, {
        anchor = "SW",
        relative = "editor",
        width = vim.o.columns,
        height = math.floor(vim.o.lines * 0.3),
        col = 0,
        row = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0),
        style = "minimal",
        border = { "─", "─", "─", "", "", "", "", "" },
      })

      api.nvim_win_set_cursor(content_window, { 1, 0 })
      win = content_window
    end

    return win
  end

  -- With focus on a popup window, any kind of "split" buffer will crash. Floating windows cannot be split.
  local ok, win = pcall(open)
  if not ok then
    self.kind = "floating"
    win = open()
  end

  -- Workaround UFO getting folds wrong.
  if package.loaded["ufo"] then
    local ufo_ok, ufo = pcall(require, "ufo")
    if ufo_ok and type(ufo.detach) == "function" then
      ufo.detach(self.handle)
    end
  end

  self.win_handle = win
  return win
end

function Buffer:is_valid()
  return api.nvim_buf_is_valid(self.handle)
end

function Buffer:create_fold(first, last, _)
  self:win_exec(string.format("%d,%dfold", first, last))
end

function Buffer:set_fold_state(first, last, open)
  self:win_exec(string.format("%d,%dfold%s", first, last, open and "open" or "close"))
end

function Buffer:unlock()
  self:set_buffer_option("readonly", false)
  self:set_buffer_option("modifiable", true)
end

function Buffer:get_option(name)
  if self.handle ~= nil then
    return api.nvim_get_option_value(name, { buf = self.handle })
  end
end

function Buffer:get_window_option(name)
  if self.win_handle ~= nil then
    return api.nvim_get_option_value(name, { win = self.win_handle })
  end
end

function Buffer:set_buffer_option(name, value)
  if self.handle ~= nil then
    if vim.fn.has("nvim-0.11") == 1 then
      api.nvim_set_option_value(name, value, { scope = "local", buf = self.handle })
    else
      api.nvim_set_option_value(name, value, { buf = self.handle })
    end
  end
end

function Buffer:set_window_option(name, value)
  if self.win_handle ~= nil then
    api.nvim_set_option_value(name, value, { scope = "local", win = self.win_handle })
  end
end

function Buffer:set_name(name)
  api.nvim_buf_set_name(self.handle, name)
end

function Buffer:replace_content_with(lines)
  api.nvim_buf_set_lines(self.handle, 0, -1, false, lines)
  self:write()
end

function Buffer:add_highlight(line, col_start, col_end, name, namespace)
  local ns_id = self:get_namespace_id(namespace)
  if ns_id then
    api.nvim_buf_add_highlight(self.handle, ns_id, name, line, col_start, col_end)
  end
end

function Buffer:place_sign(line, name, opts)
  opts = opts or {}

  local ns_id = self:get_namespace_id(opts.namespace)
  if ns_id then
    api.nvim_buf_set_extmark(self.handle, ns_id, line - 1, 0, {
      sign_text = signs_get(name),
      sign_hl_group = opts.highlight,
      cursorline_hl_group = opts.cursor_hl,
    })
  end
end

function Buffer:add_line_highlight(line, hl_group, opts)
  opts = opts or {}

  local ns_id = self:get_namespace_id(opts.namespace)
  if ns_id then
    api.nvim_buf_set_extmark(
      self.handle,
      ns_id,
      line,
      0,
      { line_hl_group = hl_group, priority = opts.priority or 190 }
    )
  end
end

function Buffer:clear_namespace(name)
  assert(name, "Cannot clear namespace without specifying which")

  if not self:is_focused() then
    return
  end

  local ns_id = self:get_namespace_id(name)
  if ns_id then
    api.nvim_buf_clear_namespace(self.handle, ns_id, 0, -1)
  end
end

function Buffer:create_namespace(name)
  assert(name, "Namespace must have a name")

  local namespace = "maju-buffer-" .. self.handle .. "-" .. name
  if not self.namespaces[namespace] then
    self.namespaces[namespace] = api.nvim_create_namespace(namespace)
  end

  return self.namespaces[namespace]
end

---@param name string
---@return number|nil
function Buffer:get_namespace_id(name)
  local ns_id
  if name and name ~= "default" then
    ns_id = self.namespaces["maju-buffer-" .. self.handle .. "-" .. name]
  else
    ns_id = self.namespaces.default
  end

  return ns_id
end

function Buffer:set_filetype(ft)
  self:set_buffer_option("filetype", ft)
end

function Buffer:call(f, ...)
  local args = { ... }
  api.nvim_buf_call(self.handle, function()
    f(unpack(args))
  end)
end

function Buffer:win_call(f, ...)
  if self.win_handle and api.nvim_win_is_valid(self.win_handle) then
    local args = { ... }
    api.nvim_win_call(self.win_handle, function()
      f(unpack(args))
    end)
  end
end

function Buffer:chan_send(data)
  assert(self.chan, "Terminal channel not open")
  assert(data, "data cannot be nil")
  api.nvim_chan_send(self.chan, data)
end

function Buffer:open_terminal_channel()
  assert(self.chan == nil, "Terminal channel already open")

  self.chan = api.nvim_open_term(self.handle, {})
  assert(self.chan > 0, "Failed to open terminal channel")

  self:unlock()
  self:set_lines(0, -1, false, {})
  self:lock()
end

function Buffer:close_terminal_channel()
  assert(self.chan, "No terminal channel to close")

  fn.chanclose(self.chan)
  self.chan = nil
end

function Buffer:win_exec(cmd)
  fn.win_execute(self.win_handle, cmd)
end

function Buffer:exists()
  return fn.bufnr(self.handle) ~= -1
end

function Buffer:set_extmark(...)
  return api.nvim_buf_set_extmark(self.handle, ...)
end

function Buffer:set_decorations(namespace, opts)
  local ns_id = self:get_namespace_id(namespace)
  if ns_id then
    return api.nvim_set_decoration_provider(ns_id, opts)
  end
end

function Buffer:line_count()
  return api.nvim_buf_line_count(self.handle)
end

function Buffer:resize_header()
  if not self.header_win_handle then
    return
  end

  api.nvim_win_set_width(self.header_win_handle, fn.winwidth(self.win_handle))
end

---@param text string
---@param scroll boolean
function Buffer:set_header(text, scroll)
  self:set_extmark(self:get_namespace_id("default"), 0, 0, {
    virt_lines = { { { "", "MajuChangeId" } } },
    virt_lines_above = true,
  })

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, { (" %s"):format(text) })
  vim.bo[buf].undolevels = -1
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modified = false

  local winid = api.nvim_open_win(buf, false, {
    relative = "win",
    win = self.win_handle,
    width = fn.winwidth(self.win_handle),
    height = 1,
    row = 0,
    col = 0,
    focusable = false,
    style = "minimal",
    noautocmd = true,
    border = "none",
  })
  vim.wo[winid].wrap = false
  vim.wo[winid].winhl = "NormalFloat:MajuFloatHeader"

  fn.matchadd("MajuFloatHeaderHighlight", [[\v\<cr\>|\<esc\>]], 100, -1, { window = winid })
  self.header_win_handle = winid

  if scroll then
    self:call(function()
      local keys = vim.api.nvim_replace_termcodes("<c-u>", true, false, true)
      vim.api.nvim_feedkeys(keys, "n", false)
    end)
  end

  api.nvim_create_autocmd("WinResized", {
    callback = function()
      self:resize_header()
    end,
    buffer = self.handle,
    group = self.autocmd_group,
  })
end

---@class BufferConfig
---@field name string
---@field kind string
---@field filetype string|nil
---@field bufhidden string|nil
---@field header string|nil
---@field scroll_header boolean|nil
---@field buftype string|nil|boolean
---@field cwd string|nil
---@field status_column string|nil
---@field load boolean|nil
---@field context_highlight boolean|nil
---@field open boolean|nil
---@field disable_line_numbers boolean|nil
---@field disable_relative_line_numbers boolean|nil
---@field disable_signs boolean|nil
---@field swapfile boolean|nil
---@field modifiable boolean|nil
---@field readonly boolean|nil
---@field mappings table|nil
---@field user_mappings table|nil
---@field autocmds table|nil
---@field user_autocmds table|nil
---@field spell_check boolean|nil
---@field initialize function|nil
---@field after function|nil
---@field on_detach function|nil
---@field render function|nil
---@field foldmarkers boolean|nil

---@param config BufferConfig
---@return Buffer
function Buffer.create(config)
  assert(config, "Buffers work better if you configure them")

  local buffer = Buffer.from_name(config.name)

  buffer.name = config.name
  buffer.kind = config.kind or "split"

  if config.load then
    buffer:replace_content_with(vim.fn.readfile(config.name))
  end

  local win
  if config.open ~= false then
    win = buffer:show()
  end

  buffer:set_buffer_option("swapfile", false)
  buffer:set_buffer_option("modeline", false)
  buffer:set_buffer_option("bufhidden", config.bufhidden or "wipe")
  buffer:set_buffer_option("modifiable", config.modifiable or false)
  buffer:set_buffer_option("modified", config.modifiable or false)
  buffer:set_buffer_option("readonly", config.readonly or false)

  if config.buftype ~= false then
    buffer:set_buffer_option("buftype", config.buftype or "nofile")
  end

  if config.filetype then
    buffer:set_filetype(config.filetype)
  end

  if config.status_column then
    buffer:set_window_option("statuscolumn", config.status_column)
    buffer:set_window_option("signcolumn", "no")
  end

  if config.user_mappings then
    local opts = { buffer = buffer.handle, silent = true, nowait = true }
    for key, cb in pairs(config.user_mappings) do
      vim.keymap.set("n", key, cb, opts)
    end
  end

  if config.mappings then
    for mode, val in pairs(config.mappings) do
      for key, cb in pairs(val) do
        local map_fn = function()
          cb(buffer)

          if mode == "v" then
            api.nvim_feedkeys(api.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
          end
        end

        local opts = { buffer = buffer.handle, silent = true, nowait = true }

        for _, k in ipairs(util.tbl_wrap(key)) do
          vim.keymap.set(mode, k, map_fn, opts)
        end
      end
    end
  end

  if config.initialize then
    config.initialize(buffer, win)
  end

  if win then
    buffer:set_window_option("foldenable", true)
    buffer:set_window_option("foldlevel", 99)
    buffer:set_window_option("foldminlines", 0)
    buffer:set_window_option("foldtext", "")
    buffer:set_window_option("foldcolumn", "0")
    buffer:set_window_option("listchars", "")
    buffer:set_window_option("list", false)
    buffer:call(function()
      vim.opt_local.winhl:append("Folded:MajuFold")
      vim.opt_local.winhl:append("FoldColumn:MajuFold")
      vim.opt_local.winhl:append("SignColumn:MajuSignColumn")
      vim.opt_local.winhl:append("Normal:MajuNormal")
      vim.opt_local.winhl:append("NormalFloat:MajuNormalFloat")
      vim.opt_local.winhl:append("FloatBorder:MajuFloatBorder")
      vim.opt_local.winhl:append("WinSeparator:MajuWinSeparator")
      vim.opt_local.winhl:append("CursorLineNr:MajuCursorLineNr")
      vim.opt_local.fillchars:append("fold: ")
    end)

    if (config.disable_line_numbers == nil) or config.disable_line_numbers then
      buffer:set_window_option("number", false)
    end

    if (config.disable_relative_line_numbers == nil) or config.disable_relative_line_numbers then
      buffer:set_window_option("relativenumber", false)
    end

    buffer:set_window_option("spell", config.spell_check or false)
    buffer:set_window_option("wrap", false)
    buffer:set_window_option("foldmethod", "manual")
  end

  if config.render then
    buffer.ui:render(unpack(config.render(buffer)))
  end

  for event, callback in pairs(config.autocmds or {}) do
    api.nvim_create_autocmd(event, {
      callback = callback,
      buffer = buffer.handle,
      group = buffer.autocmd_group,
    })
  end

  for event, callback in pairs(config.user_autocmds or {}) do
    api.nvim_create_autocmd("User", {
      pattern = event,
      callback = callback,
      group = buffer.autocmd_group,
    })
  end

  if config.after then
    buffer:call(function()
      config.after(buffer, win)
    end)
  end

  api.nvim_buf_attach(buffer.handle, false, {
    on_detach = function()
      if config.on_detach then
        config.on_detach(buffer)
      end

      if config.autocmds or config.user_autocmds then
        pcall(api.nvim_del_augroup_by_id, buffer.autocmd_group)
      end

      if buffer.header_win_handle ~= nil then
        vim.schedule(function()
          pcall(api.nvim_win_close, buffer.header_win_handle, true)
        end)
      end
    end,
  })

  if config.context_highlight then
    buffer:create_namespace("ViewContext")
    buffer:set_decorations("ViewContext", {
      on_start = function()
        return buffer:exists() and buffer:is_valid() and buffer:is_focused()
      end,
      on_win = function()
        buffer:clear_namespace("ViewContext")

        local context = buffer.ui:get_cursor_context()
        if not context then
          return
        end

        local cursor = fn.line(".")
        local start = math.max(context.position.row_start, fn.line("w0"))
        local stop = math.min(context.position.row_end, fn.line("w$"))
        local disable_hl = vim.b.maju_disable_hunk_highlight == true

        for line = start, stop do
          local is_cursor = line == cursor
          if is_cursor or not disable_hl then
            local line_hl = ("%s%s"):format(
              buffer.ui:get_line_highlight(line) or "MajuDiffContext",
              is_cursor and "Cursor" or "Highlight"
            )

            buffer:add_line_highlight(line - 1, line_hl, {
              priority = 200,
              namespace = "ViewContext",
            })
          end
        end
      end,
    })
  end

  if config.foldmarkers then
    buffer:set_window_option("signcolumn", "auto")

    buffer:create_namespace("FoldSigns")
    buffer:set_decorations("FoldSigns", {
      on_start = function()
        return buffer:exists() and buffer:is_valid() and buffer:is_focused()
      end,
      on_win = function()
        buffer:clear_namespace("FoldSigns")
        local foldmarkers = buffer.ui.statuscolumn.foldmarkers
        for line = fn.line("w0"), fn.line("w$") do
          if foldmarkers[line] then
            local fold

            if fn.foldclosed(line) == -1 then
              fold = "MajuOpen"
            else
              fold = "MajuClosed"
            end

            buffer:place_sign(line, fold .. string.lower(foldmarkers[line]), {
              namespace = "FoldSigns",
              highlight = "MajuSubtleText",
              cursor_hl = "MajuCursorLine",
            })
          else
            buffer:place_sign(line, "MajuBlank", {
              namespace = "FoldSigns",
              cursor_hl = "MajuCursorLine",
            })
          end
        end
      end,
    })
  end

  if config.header then
    buffer:set_header(config.header, config.scroll_header)
  end

  if config.cwd then
    buffer:win_exec("lcd " .. fn.fnameescape(config.cwd))
  end

  return buffer
end

---@param name string
---@return Buffer
function Buffer.from_name(name)
  local buffer_handle = fn.bufnr(name)
  if buffer_handle == -1 then
    buffer_handle = api.nvim_create_buf(false, false)
    api.nvim_buf_set_name(buffer_handle, name)
  end

  local window_handle = fn.win_findbuf(buffer_handle)

  return Buffer:new(buffer_handle, window_handle[1])
end

return Buffer
