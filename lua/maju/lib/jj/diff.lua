local jj = require("maju.lib.jj.cli")

local M = {}

local insert = table.insert
local sha256 = vim.fn.sha256

---@class Diff
---@field kind string
---@field lines string[]
---@field file string
---@field info table
---@field hunks Hunk[]

---@class Hunk
---@field file string
---@field index_from number
---@field index_len number
---@field disk_from number
---@field disk_len number
---@field diff_from number
---@field diff_to number
---@field length number
---@field hash string
---@field line string
---@field lines string[]

---@param content string[]
---@return string
local function hunk_hash(content)
  return sha256(table.concat(content, "\n"))
end

---@param output string[]
---@return string[], number
local function build_diff_header(output)
  local header = {}
  local start_idx = 1

  for i = start_idx, #output do
    local line = output[i]
    if line:match("^@@@*.*@@@*") then
      start_idx = i
      break
    end
    insert(header, line)
  end

  return header, start_idx
end

---@param header string[]
---@return string, string[]
local function build_kind(header)
  local kind = ""
  local info = {}
  local header_count = #header

  if header_count >= 4 and header[2]:match("^similarity index") then
    -- Check for copy vs rename
    if header[3]:match("^copy from") then
      kind = "copied"
    else
      kind = "renamed"
    end
    info = { header[3], header[4] }
  elseif header_count == 4 then
    kind = "modified"
  elseif header_count == 5 then
    kind = header[2]:match("(.*) mode %d+") or header[3]:match("(.*) mode %d+")
  end

  return kind, info
end

---@param header string[]
---@param kind string
---@return string
local function build_file(header, kind)
  if kind == "modified" then
    return header[3]:match("%-%-%- ./(.*)")
  elseif kind == "renamed" then
    return ("%s -> %s"):format(header[3]:match("rename from (.*)"), header[4]:match("rename to (.*)"))
  elseif kind == "copied" then
    return ("%s -> %s"):format(header[3]:match("copy from (.*)"), header[4]:match("copy to (.*)"))
  elseif kind == "new file" then
    return header[5]:match("%+%+%+ b/(.*)")
  elseif kind == "deleted file" then
    return header[4]:match("%-%-%- a/(.*)")
  else
    return ""
  end
end

---@param output string[]
---@param start_idx number
---@return string[]
local function build_lines(output, start_idx)
  if start_idx == 1 then
    return output
  end

  local lines = {}
  for i = start_idx, #output do
    insert(lines, output[i])
  end
  return lines
end

---@param lines string[]
---@return Hunk[]
local function build_hunks(lines)
  local hunks = {}
  local hunk = nil
  local hunk_content = {}

  for i = 1, #lines do
    local line = lines[i]
    if not line:match("^%+%+%+") then
      local index_from, index_len, disk_from, disk_len

      if line:match("^@@@") then
        index_from, index_len, disk_from, disk_len = line:match("@@@* %-(%d+),?(%d*) .* %+(%d+),?(%d*) @@@*")
      else
        index_from, index_len, disk_from, disk_len = line:match("@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      end

      if index_from then
        if hunk ~= nil then
          hunk.hash = hunk_hash(hunk_content)
          hunk_content = {}
          insert(hunks, hunk)
        end

        hunk = {
          index_from = tonumber(index_from),
          index_len = tonumber(index_len) or 1,
          disk_from = tonumber(disk_from),
          disk_len = tonumber(disk_len) or 1,
          line = line,
          diff_from = i,
          diff_to = i,
        }
      else
        insert(hunk_content, line)

        if hunk then
          hunk.diff_to = hunk.diff_to + 1
        end
      end
    end
  end

  if hunk then
    hunk.hash = hunk_hash(hunk_content)
    insert(hunks, hunk)
  end

  for _, h in ipairs(hunks) do
    h.lines = {}
    for i = h.diff_from + 1, h.diff_to do
      insert(h.lines, lines[i])
    end
    h.length = h.diff_to - h.diff_from
  end

  return hunks
end

---@param raw_diff string[]
---@return Diff
function M.parse_diff(raw_diff)
  local header, start_idx = build_diff_header(raw_diff)
  local lines = build_lines(raw_diff, start_idx)
  local hunks = build_hunks(lines)
  local kind, info = build_kind(header)
  local file = build_file(header, kind)

  for _, hunk in ipairs(hunks) do
    hunk.file = file
  end

  return {
    kind = kind,
    lines = lines,
    file = file,
    info = info,
    hunks = hunks,
  }
end

---@param raw_output string[]
---@return string[][]
local function split_multi_file_diff(raw_output)
  local diffs = {}
  local current = {}

  for _, line in ipairs(raw_output) do
    if line:match("^diff %-%-git a/.* b/.*") then
      if #current > 0 then
        insert(diffs, current)
      end
      current = { line }
    else
      insert(current, line)
    end
  end

  if #current > 0 then
    insert(diffs, current)
  end

  return diffs
end

---@param revision string
---@param filename string
---@return Diff|nil
function M.get_file_diff(revision, filename)
  local result = jj.diff.git_format.revision(revision).files(filename).call({ ignore_error = true })
  if result.code ~= 0 or #result.stdout == 0 then
    return nil
  end
  return M.parse_diff(result.stdout)
end

---@param revision string
---@return Diff[]
function M.get_all_diffs(revision)
  local result = jj.diff.git_format.revision(revision).call({ ignore_error = true })
  if result.code ~= 0 or #result.stdout == 0 then
    return {}
  end

  local raw_diffs = split_multi_file_diff(result.stdout)
  local diffs = {}
  for _, raw in ipairs(raw_diffs) do
    insert(diffs, M.parse_diff(raw))
  end
  return diffs
end

---@param file_item table
---@param revision string
function M.build_metatable(file_item, revision)
  setmetatable(file_item, {
    __index = function(self, method)
      if method == "diff" then
        local diff = M.get_file_diff(revision, self.name)
        rawset(self, "diff", diff)
        return diff
      end
    end,
  })
end

return M
