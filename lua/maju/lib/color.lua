local clamp = require("maju.lib.util").clamp
local M = {}

---@class Color
---@field red number
---@field green number
---@field blue number
---@field alpha number
local Color = setmetatable({}, {})

function Color:init(r, g, b, a)
  self:set_red(r)
  self:set_green(g)
  self:set_blue(b)
  self:set_alpha(a)
end

---@param h number Hue [0,360)
---@param s number Saturation [0,1]
---@param v number Value [0,1]
---@param a number|nil Alpha [0,1]
---@return Color
function Color.from_hsv(h, s, v, a)
  h = h % 360
  s = clamp(s, 0, 1)
  v = clamp(v, 0, 1)
  a = clamp(a or 1, 0, 1)

  local function f(n)
    local k = (n + h / 60) % 6
    return v - v * s * math.max(math.min(k, 4 - k, 1), 0)
  end

  return Color(f(5), f(3), f(1), a)
end

---@param h number Hue [0,360)
---@param s number Saturation [0,1]
---@param l number Lightness [0,1]
---@param a number|nil Alpha [0,1]
---@return Color
function Color.from_hsl(h, s, l, a)
  h = h % 360
  s = clamp(s, 0, 1)
  l = clamp(l, 0, 1)
  a = clamp(a or 1, 0, 1)
  local _a = s * math.min(l, 1 - l)

  local function f(n)
    local k = (n + h / 30) % 12
    return l - _a * math.max(math.min(k - 3, 9 - k, 1), -1)
  end

  return Color(f(0), f(8), f(4), a)
end

---@param c number|string Hex number or css-style `#RRGGBB[AA]`
---@return Color
function Color.from_hex(c)
  local n = c
  if type(c) == "string" then
    local s = c:lower():match("#?([a-f0-9]+)")
    n = tonumber(s, 16)
    if #s <= 6 then
      n = bit.lshift(n, 8) + 0xff
    end
  end

  return Color(
    bit.rshift(n, 24) / 0xff,
    bit.band(bit.rshift(n, 16), 0xff) / 0xff,
    bit.band(bit.rshift(n, 8), 0xff) / 0xff,
    bit.band(n, 0xff) / 0xff
  )
end

---@param f number Amount [-1,1]
---@return Color
function Color:shade(f)
  local t = f < 0 and 0 or 1.0
  local p = f < 0 and f * -1.0 or f

  return Color(
    (t - self.red) * p + self.red,
    (t - self.green) * p + self.green,
    (t - self.blue) * p + self.blue,
    self.alpha
  )
end

---@return HSV
function Color:to_hsv()
  local r, g, b = self.red, self.green, self.blue
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local delta = max - min
  local h, s = 0, 0

  if max == min then
    h = 0
  elseif max == r then
    h = 60 * ((g - b) / delta)
  elseif max == g then
    h = 60 * ((b - r) / delta + 2)
  elseif max == b then
    h = 60 * ((r - g) / delta + 4)
  end

  if h < 0 then
    h = h + 360
  end
  if max ~= 0 then
    s = (max - min) / max
  end

  return { hue = h, saturation = s, value = max }
end

---@param v number Saturation [0,1]
---@return Color
function Color:set_saturation(v)
  local hsv = self:to_hsv()
  hsv.saturation = clamp(v, 0, 1)
  local c = Color.from_hsv(hsv.hue, hsv.saturation, hsv.value)
  self._red = c.red
  self._green = c.green
  self._blue = c.blue
  return self
end

---@return string CSS hex `#rrggbb`
function Color:to_css()
  local n = bit.bor(
    bit.bor((self.blue * 0xff), bit.lshift((self.green * 0xff), 8)),
    bit.lshift((self.red * 0xff), 16)
  )
  return string.format("#%06x", n)
end

function Color:set_red(v)
  self._red = clamp(v or 1.0, 0, 1)
  return self
end

function Color:set_green(v)
  self._green = clamp(v or 1.0, 0, 1)
  return self
end

function Color:set_blue(v)
  self._blue = clamp(v or 1.0, 0, 1)
  return self
end

function Color:set_alpha(v)
  self._alpha = clamp(v or 1.0, 0, 1)
  return self
end

do
  local getters = {
    red = function(self) return self._red end,
    green = function(self) return self._green end,
    blue = function(self) return self._blue end,
    alpha = function(self) return self._alpha end,
  }

  function Color.__index(self, k)
    if getters[k] then
      return getters[k](self)
    end
    return Color[k]
  end

  function Color.__newindex(self, k, v)
    local setters = {
      red = Color.set_red,
      green = Color.set_green,
      blue = Color.set_blue,
      alpha = Color.set_alpha,
    }
    if setters[k] then
      setters[k](self, v)
    else
      rawset(self, k, v)
    end
  end

  local mt = getmetatable(Color)
  function mt.__call(_, ...)
    local this = setmetatable({}, Color)
    this:init(...)
    return this
  end
end

M.Color = Color

return M
