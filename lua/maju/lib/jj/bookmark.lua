local jj = require("maju.lib.jj.cli")

local M = {}

local LIST_TEMPLATE = 'name ++ "\x00" ++ if(remote, remote, "") ++ "\x00" ++ normal_target.map(|c| c.change_id().short(8)).join(",") ++ "\n"'

---@class BookmarkEntry
---@field name string
---@field remote string
---@field target string

---@return BookmarkEntry[]
function M.list()
  local result = jj.bookmark.list.all_remotes.template(LIST_TEMPLATE).call({ ignore_error = true })
  if result.code ~= 0 then
    return {}
  end

  local entries = {}
  for _, line in ipairs(result.stdout) do
    if line ~= "" then
      local parts = vim.split(line, "\0", { plain = true })
      if #parts >= 3 then
        table.insert(entries, {
          name = parts[1],
          remote = parts[2],
          target = parts[3],
        })
      end
    end
  end
  return entries
end

---@param name string
---@param revision? string
---@return {success: boolean, error: string|nil}
function M.create(name, revision)
  local cmd = jj.bookmark.create
  if revision then
    cmd = cmd.revision(revision)
  end
  cmd = cmd.args(name)
  local result = cmd.call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param name string
---@return {success: boolean, error: string|nil}
function M.delete(name)
  local result = jj.bookmark.delete.args(name).call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param old_name string
---@param new_name string
---@return {success: boolean, error: string|nil}
function M.rename(old_name, new_name)
  local result = jj.bookmark.rename.args(old_name, new_name).call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param name string
---@param opts? {to?: string, from?: string, allow_backwards?: boolean}
---@return {success: boolean, error: string|nil}
function M.move(name, opts)
  opts = opts or {}
  local cmd = jj.bookmark.move.args(name)
  if opts.to then
    cmd = cmd.to(opts.to)
  end
  if opts.from then
    cmd = cmd.from(opts.from)
  end
  if opts.allow_backwards then
    cmd = cmd.allow_backwards
  end
  local result = cmd.call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param name string
---@param revision? string
---@return {success: boolean, error: string|nil}
function M.set(name, revision)
  local cmd = jj.bookmark.set
  if revision then
    cmd = cmd.revision(revision)
  end
  cmd = cmd.args(name)
  local result = cmd.call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param bookmark string bookmark@remote format
---@return {success: boolean, error: string|nil}
function M.track(bookmark)
  local result = jj.bookmark.track.args(bookmark).call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@param bookmark string bookmark@remote format
---@return {success: boolean, error: string|nil}
function M.untrack(bookmark)
  local result = jj.bookmark.untrack.args(bookmark).call({ ignore_error = true })
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

---@return string[]
function M.get_all_names()
  local entries = M.list()
  local names = {}
  local seen = {}
  for _, entry in ipairs(entries) do
    if entry.remote == "" and not seen[entry.name] then
      table.insert(names, entry.name)
      seen[entry.name] = true
    end
  end
  return names
end

return M
