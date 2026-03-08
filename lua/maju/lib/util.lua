local M = {}

---@generic T: any
---@generic U: any
---@param tbl T[]
---@param f fun(v: T): U
---@return U[]
function M.map(tbl, f)
  local t = {}
  for k, v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

---@generic T: any
---@param tbl T[][]
---@return T[]
function M.flatten(tbl)
  local t = {}
  for _, v in ipairs(tbl) do
    for _, item in ipairs(v) do
      table.insert(t, item)
    end
  end
  return t
end

---@generic T: any
---@generic U: any
---@param tbl T[]
---@param f fun(v: T): U
---@return U[]
function M.flat_map(tbl, f)
  return M.flatten(M.map(tbl, f))
end

---@generic T: any
---@param tbl T[]
---@param f fun(v: T): boolean
---@return T[]
function M.filter(tbl, f)
  return vim.tbl_filter(f, tbl)
end

---@generic T: any
---@generic U: any
---@param list T[]
---@param f fun(v: T): U|nil
---@return U[]
function M.filter_map(list, f)
  local t = {}
  for _, v in ipairs(list) do
    local result = f(v)
    if result ~= nil then
      table.insert(t, result)
    end
  end
  return t
end

---@param tbl table
---@param sep any
---@return table
function M.intersperse(tbl, sep)
  local t = {}
  local len = #tbl
  for i = 1, len do
    table.insert(t, tbl[i])
    if i ~= len then
      table.insert(t, sep)
    end
  end
  return t
end

--- Merge multiple list-like tables into one
---@param ... table
---@return table
function M.merge(...)
  local res = {}
  for _, tbl in ipairs { ... } do
    for _, item in ipairs(tbl) do
      table.insert(res, item)
    end
  end
  return res
end

---@param tbl table
---@return table
function M.deduplicate(tbl)
  local res = {}
  for i = 1, #tbl do
    if tbl[i] and not vim.tbl_contains(res, tbl[i]) then
      table.insert(res, tbl[i])
    end
  end
  return res
end

---@param tbl table
---@return table
function M.reverse(tbl)
  local t = {}
  local c = #tbl + 1
  for i, v in ipairs(tbl) do
    t[c - i] = v
  end
  return t
end

function M.trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function M.deepcopy(o)
  local mt = getmetatable(o)
  local copy = vim.deepcopy(o)
  if mt then
    setmetatable(copy, mt)
  end
  return copy
end

function M.split(str, sep)
  if str == "" then
    return {}
  end
  return vim.split(str, sep)
end

---@param tbl table
---@return integer
function M.max_length(tbl)
  local max = 0
  for _, v in ipairs(tbl) do
    if #v > max then
      max = #v
    end
  end
  return max
end

function M.pad_right(s, len)
  return s .. string.rep(" ", math.max(len - #s, 0))
end

function M.pad_left(s, len)
  return string.rep(" ", math.max(len - #s, 0)) .. s
end

function M.str_truncate(str, max_length, trailing)
  trailing = trailing or "..."
  if vim.fn.strdisplaywidth(str) > max_length then
    str = vim.trim(str:sub(1, max_length - #trailing)) .. trailing
  end
  return str
end

function M.str_min_width(str, len, sep, opts)
  local mode = (type(opts) == "table" and opts.mode) or "append"
  local length = vim.fn.strdisplaywidth(str)
  if length > len then
    return str
  end
  if mode == "append" then
    return str .. string.rep(sep or " ", len - length)
  else
    return string.rep(sep or " ", len - length) .. str
  end
end

function M.str_clamp(str, len, sep, opts)
  opts = (type(opts) == "table" and opts.mode) or { mode = "append" }
  return M.str_min_width(M.str_truncate(str, len - 1, ""), len, sep or " ", opts)
end

---@param tbl table
---@return table
function M.build_reverse_lookup(tbl)
  local result = {}
  for i, v in ipairs(tbl) do
    table.insert(result, v)
    result[v] = i
  end
  return result
end

function M.find(tbl, cond)
  for i = 1, #tbl do
    if cond(tbl[i]) then
      return tbl[i]
    end
  end
end

---@param tbl table
---@param s integer
---@param e? integer
---@return table
function M.slice(tbl, s, e)
  local pos, new = 1, {}
  e = e or #tbl
  for i = s, e do
    new[pos] = tbl[i]
    pos = pos + 1
  end
  return new
end

function M.remove_ansi_escape_codes(s)
  s, _ = s:gsub("[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", "")
  s, _ = s:gsub("[\r\n\04\08]", "")
  return s
end

function M.safe_win_close(winid, force)
  local ok = pcall(vim.api.nvim_win_close, winid, force)
  if not ok then
    pcall(vim.cmd, "b#")
  end
end

---@param value any
---@return table
function M.tbl_wrap(value)
  return type(value) == "table" and value or { value }
end

function M.pattern_escape(str)
  local special_chars = { "%%", "%(", "%)", "%.", "%+", "%-", "%*", "%?", "%[", "%^", "%$" }
  for _, char in ipairs(special_chars) do
    str, _ = str:gsub(char, "%" .. char)
  end
  return str
end

---@param v number
---@param min number
---@param max number
---@return number
function M.clamp(v, min, max)
  return math.min(math.max(v, min), max)
end

return M
