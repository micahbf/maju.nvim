local Color = require("maju.lib.color").Color
local M = {}

---@param dec number
---@return string
local function to_hex(dec)
  local hex = string.format("%x", dec)
  if #hex < 6 then
    return string.rep("0", 6 - #hex) .. hex
  else
    return hex
  end
end

---@param name string Highlight group name
---@return string|nil
local function get_fg(name)
  local color = vim.api.nvim_get_hl(0, { name = name })
  if color["link"] then
    return get_fg(color["link"])
  elseif color["reverse"] and color["bg"] then
    return "#" .. to_hex(color["bg"])
  elseif color["fg"] then
    return "#" .. to_hex(color["fg"])
  end
end

---@param name string Highlight group name
---@return string|nil
local function get_bg(name)
  local color = vim.api.nvim_get_hl(0, { name = name })
  if color["link"] then
    return get_bg(color["link"])
  elseif color["reverse"] and color["fg"] then
    return "#" .. to_hex(color["fg"])
  elseif color["bg"] then
    return "#" .. to_hex(color["bg"])
  end
end

---@return table
local function make_palette()
  local config = require("maju.config")
  local user_hl = config.values.highlight or {}

  local bg      = Color.from_hex(get_bg("Normal") or (vim.o.bg == "dark" and "#22252A" or "#eeeeee"))
  local fg      = Color.from_hex((vim.o.bg == "dark" and "#fcfcfc" or "#22252A"))

  -- Use a curated palette. Syntax group colors (Error, PreProc, Macro, etc.) don't
  -- have consistent semantic meaning across colorschemes — e.g. kanagawa maps PreProc,
  -- Macro, and Include all to the same pink. Users can override via config.highlight.
  local red     = Color.from_hex(user_hl.red    or "#FF5D62")
  local orange  = Color.from_hex(user_hl.orange or "#FFA066")
  local yellow  = Color.from_hex(user_hl.yellow or "#E6C384")
  local green   = Color.from_hex(user_hl.green  or "#98BB6C")
  local cyan    = Color.from_hex(user_hl.cyan   or "#7FB4CA")
  local blue    = Color.from_hex(user_hl.blue   or "#7E9CD8")
  local purple  = Color.from_hex(user_hl.purple or "#957FB8")

  local f = vim.o.bg == "dark" and 1 or -1

  return {
    bg0        = bg:to_css(),
    bg1        = bg:shade(f * 0.019):to_css(),
    bg2        = bg:shade(f * 0.065):to_css(),
    bg3        = bg:shade(f * 0.11):to_css(),
    grey       = bg:shade(f * 0.4):to_css(),
    white      = fg:to_css(),
    red        = red:to_css(),
    bg_red     = red:shade(f * -0.18):to_css(),
    line_red   = get_bg("DiffDelete") or red:shade(f * -0.6):set_saturation(0.4):to_css(),
    orange     = orange:to_css(),
    bg_orange  = orange:shade(f * -0.17):to_css(),
    yellow     = yellow:to_css(),
    bg_yellow  = yellow:shade(f * -0.17):to_css(),
    green      = green:to_css(),
    bg_green   = green:shade(f * -0.18):to_css(),
    line_green = get_bg("DiffAdd") or green:shade(f * -0.72):set_saturation(0.2):to_css(),
    cyan       = cyan:to_css(),
    bg_cyan    = cyan:shade(f * -0.18):to_css(),
    blue       = blue:to_css(),
    bg_blue    = blue:shade(f * -0.18):to_css(),
    purple     = purple:to_css(),
    bg_purple  = purple:shade(f * -0.18):to_css(),
    md_purple  = purple:shade(0.18):to_css(),
  }
end

function M.setup()
  local p = make_palette()

  -- stylua: ignore
  local highlights = {
    -- Diff
    MajuDiffContext              = { bg = p.bg1 },
    MajuDiffContextHighlight     = { bg = p.bg2 },
    MajuDiffContextCursor        = { bg = p.bg1 },
    MajuDiffAdd                  = { bg = p.line_green, fg = p.bg_green, ctermfg = 2 },
    MajuDiffAddHighlight         = { bg = p.line_green, fg = p.green, ctermfg = 2 },
    MajuDiffAddCursor            = { bg = p.bg1, fg = p.green, ctermfg = 2 },
    MajuDiffDelete               = { bg = p.line_red, fg = p.bg_red, ctermfg = 1 },
    MajuDiffDeleteHighlight      = { bg = p.line_red, fg = p.red, ctermfg = 1 },
    MajuDiffDeleteCursor         = { bg = p.bg1, fg = p.red, ctermfg = 1 },
    MajuDiffHeader               = { bg = p.bg3, fg = p.blue, bold = true, ctermfg = 4 },
    MajuDiffHeaderHighlight      = { bg = p.bg3, fg = p.orange, bold = true, ctermfg = 3 },

    -- Hunks
    MajuHunkHeader               = { fg = p.bg0, bg = p.grey, bold = true, ctermfg = 7 },
    MajuHunkHeaderHighlight      = { fg = p.bg0, bg = p.md_purple, bold = true, ctermfg = 5 },
    MajuHunkHeaderCursor         = { fg = p.bg0, bg = p.md_purple, bold = true, ctermfg = 5 },

    -- Section headers
    MajuSectionHeader            = { fg = p.purple, bold = true, ctermfg = 5 },

    -- Change IDs and metadata
    MajuChangeIdBold             = { fg = p.yellow, bold = true, ctermfg = 3 },
    MajuChangeId                 = { fg = p.bg_yellow, ctermfg = 3 },
    MajuCommitIdBold             = { fg = p.blue, bold = true, ctermfg = 4 },
    MajuCommitId                 = { fg = p.bg_blue, ctermfg = 4 },
    MajuChangeModified           = { fg = p.bg_blue, bold = true, italic = true, ctermfg = 4 },
    MajuChangeAdded              = { fg = p.bg_green, bold = true, italic = true, ctermfg = 2 },
    MajuChangeDeleted            = { fg = p.bg_red, bold = true, italic = true, ctermfg = 1 },
    MajuChangeRenamed            = { fg = p.bg_purple, bold = true, italic = true, ctermfg = 5 },

    -- Bookmarks and remotes
    MajuBookmark                 = { fg = p.blue, bold = true, ctermfg = 4 },
    MajuRemote                   = { fg = p.green, bold = true, ctermfg = 2 },

    -- UI chrome
    MajuNormal                   = { link = "Normal" },
    MajuNormalFloat              = { link = "MajuNormal" },
    MajuFloatBorder              = { link = "MajuNormalFloat" },
    MajuFold                     = { fg = "NONE", bg = "NONE" },
    MajuWinSeparator             = { link = "WinSeparator" },
    MajuCursorLine               = { link = "CursorLine" },
    MajuCursorLineNr             = { link = "CursorLineNr" },
    MajuSignColumn               = { fg = "NONE", bg = "NONE" },
    MajuFloatHeader              = { bg = p.bg0, bold = true, ctermfg = 7 },
    MajuFloatHeaderHighlight     = { bg = p.bg2, fg = p.cyan, bold = true, ctermfg = 6 },
    MajuSubtleText               = { link = "Comment" },

    -- Graph
    MajuGraphCurrent             = { fg = p.green, bold = true, ctermfg = 2 },
    MajuGraphImmutable           = { fg = p.cyan, bold = true, ctermfg = 6 },
    MajuGraphNormal              = { fg = p.grey, ctermfg = 7 },
    MajuGraphEdge                = { fg = p.grey, ctermfg = 7 },

    -- Operation log
    MajuOpId                     = { fg = p.cyan, bold = true, ctermfg = 6 },
    MajuOpCurrent                = { fg = p.green, bold = true, ctermfg = 2 },
    MajuTimestamp                = { link = "MajuSubtleText" },

    -- Describe editor
    MajuDescribeComment          = { link = "Comment" },

    -- Popup
    MajuPopupSectionTitle        = { link = "Function" },
    MajuPopupBranchName          = { link = "String" },
    MajuPopupBold                = { bold = true },
    MajuPopupSwitchKey           = { fg = p.purple, ctermfg = 5 },
    MajuPopupSwitchEnabled       = { link = "SpecialChar" },
    MajuPopupSwitchDisabled      = { link = "MajuSubtleText" },
    MajuPopupOptionKey           = { fg = p.purple, ctermfg = 5 },
    MajuPopupOptionEnabled       = { link = "SpecialChar" },
    MajuPopupOptionDisabled      = { link = "MajuSubtleText" },
    MajuPopupConfigKey           = { fg = p.purple, ctermfg = 5 },
    MajuPopupConfigEnabled       = { link = "SpecialChar" },
    MajuPopupConfigDisabled      = { link = "MajuSubtleText" },
    MajuPopupActionKey           = { fg = p.purple, ctermfg = 5 },
    MajuPopupActionDisabled      = { link = "MajuSubtleText" },
  }

  for group, hl in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, hl)
  end
end

--- Debug: dump highlight state for troubleshooting
function M.debug()
  local p = make_palette()
  local lines = { "=== Maju Highlight Debug ===" }
  table.insert(lines, "termguicolors: " .. tostring(vim.o.termguicolors))
  table.insert(lines, "")

  table.insert(lines, "-- Palette colors --")
  for _, key in ipairs({ "red", "yellow", "green", "blue", "purple", "orange", "cyan", "bg_yellow", "bg_blue", "bg_purple" }) do
    table.insert(lines, string.format("  %-12s = %s", key, p[key]))
  end
  table.insert(lines, "")

  table.insert(lines, "-- Theme source groups --")
  for _, name in ipairs({ "Error", "PreProc", "String", "Macro", "Include", "SpecialChar", "Operator" }) do
    local c = get_fg(name)
    table.insert(lines, string.format("  %-12s fg = %s", name, c or "(nil)"))
  end
  table.insert(lines, "")

  table.insert(lines, "-- Highlight group definitions --")
  for _, group in ipairs({ "MajuSectionHeader", "MajuChangeIdBold", "MajuChangeId", "MajuCommitIdBold", "MajuBookmark", "MajuChangeModified", "MajuSubtleText" }) do
    local hl = vim.api.nvim_get_hl(0, { name = group })
    table.insert(lines, string.format("  %-24s = %s", group, vim.inspect(hl)))
  end

  print(table.concat(lines, "\n"))
end

return M
