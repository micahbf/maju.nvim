local jj = require("maju.lib.jj.cli")

local M = {}

---@param result ProcessResult
---@return {success: boolean, error: string|nil}
local function wrap_result(result)
  if result.code == 0 then
    return { success = true }
  end
  return { success = false, error = table.concat(result.stderr, "\n") }
end

--- Extract the "after" content from a hunk's diff lines.
--- Includes `+` lines and context lines, excludes `-` lines.
---@param hunk_lines string[]
---@return string[]
local function hunk_after_lines(hunk_lines)
  local result = {}
  for _, line in ipairs(hunk_lines) do
    local c = line:sub(1, 1)
    if c == "+" or c == " " then
      table.insert(result, line:sub(2))
    end
  end
  return result
end

--- Extract the "before" content from a hunk's diff lines.
--- Includes `-` lines and context lines, excludes `+` lines.
---@param hunk_lines string[]
---@return string[]
local function hunk_before_lines(hunk_lines)
  local result = {}
  for _, line in ipairs(hunk_lines) do
    local c = line:sub(1, 1)
    if c == "-" or c == " " then
      table.insert(result, line:sub(2))
    end
  end
  return result
end

--- Apply selected hunks to parent content, producing patched file content.
--- Used for squash: applies working copy changes onto the parent.
---@param before string[] Parent file content lines
---@param selected_hunks table[] Hunks to apply (must have index_from, index_len, lines)
---@return string[] Patched file lines
function M.apply_selected_hunks(before, selected_hunks)
  local result = vim.deepcopy(before)

  -- Sort hunks by index_from descending to avoid offset shifts
  local sorted = vim.deepcopy(selected_hunks)
  table.sort(sorted, function(a, b)
    return a.index_from > b.index_from
  end)

  for _, hunk in ipairs(sorted) do
    local after = hunk_after_lines(hunk.lines)
    local from = hunk.index_from
    local len = hunk.index_len

    -- Remove old lines and insert new ones
    for _ = 1, len do
      table.remove(result, from)
    end
    for i, line in ipairs(after) do
      table.insert(result, from + i - 1, line)
    end
  end

  return result
end

--- Apply a partial hunk: only selected lines within a hunk.
--- Lines inside [from, to] have their changes applied; lines outside keep original.
---@param before string[] Parent file content lines
---@param hunk table Hunk object with index_from, index_len, lines
---@param sel_from number Offset from hunk start (0-indexed, relative to hunk content lines)
---@param sel_to number Offset from hunk start (0-indexed, relative to hunk content lines)
---@return string[] Patched file lines
function M.apply_partial_hunk(before, hunk, sel_from, sel_to)
  local result = vim.deepcopy(before)

  -- Build replacement lines with partial selection
  local replacement = {}
  for i, line in ipairs(hunk.lines) do
    local c = line:sub(1, 1)
    local idx = i - 1 -- 0-indexed offset
    local content = line:sub(2)

    if c == " " then
      -- Context: always include
      table.insert(replacement, content)
    elseif idx >= sel_from and idx <= sel_to then
      -- Inside selection: apply changes
      if c == "+" then
        table.insert(replacement, content)
      end
      -- "-" lines inside selection: exclude (apply the deletion)
    else
      -- Outside selection: keep original
      if c == "-" then
        table.insert(replacement, content)
      end
      -- "+" lines outside selection: exclude (don't apply the addition)
    end
  end

  local from = hunk.index_from
  local len = hunk.index_len

  for _ = 1, len do
    table.remove(result, from)
  end
  for i, line in ipairs(replacement) do
    table.insert(result, from + i - 1, line)
  end

  return result
end

--- Write a manifest JSON file to a tempfile.
---@param manifest table Manifest data
---@return string path Path to the tempfile
local function write_manifest(manifest)
  local path = vim.fn.tempname() .. ".json"
  local json = vim.json.encode(manifest)
  vim.fn.writefile({ json }, path)
  return path
end

--- Build a manifest entry for a single file with patched content.
---@param content_path string Path to the patched content file
---@return table entry Manifest file entry
local function build_manifest_entry(content_path)
  return { action = "hunks", content_file = content_path }
end

--- Squash selected hunks from working copy to parent.
---@param filename string File path relative to repo root
---@param hunks table[] Selected hunks to squash
---@param diff table Full file diff
---@param opts? {partial?: boolean, sel_from?: number, sel_to?: number}
---@return {success: boolean, error: string|nil}
function M.squash_hunks(filename, hunks, diff, opts)
  opts = opts or {}

  -- Read parent file content
  local parent_result = jj.file.show.revision("@-").args(filename).call({ ignore_error = true })
  local before = parent_result.code == 0 and parent_result.stdout or {}

  -- Apply selected hunks to get patched content
  local patched
  if opts.partial and opts.sel_from and opts.sel_to and #hunks == 1 then
    patched = M.apply_partial_hunk(before, hunks[1], opts.sel_from, opts.sel_to)
  else
    patched = M.apply_selected_hunks(before, hunks)
  end

  -- Write patched content to tempfile
  local content_path = vim.fn.tempname()
  vim.fn.writefile(patched, content_path)

  -- Build and write manifest
  local manifest = {
    mode = "include",
    files = {
      [filename] = build_manifest_entry(content_path),
    },
  }
  local manifest_path = write_manifest(manifest)

  -- Find the maju-diff-tool script path
  local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""
  local tool_path = vim.fn.fnamemodify(script_dir .. "../../../../scripts/maju-diff-tool", ":p")

  -- Call jj squash with the diff tool
  local result = jj.squash.tool(tool_path).env({ MAJU_MANIFEST = manifest_path }).files(filename).call({ ignore_error = true })

  -- Clean up tempfiles
  pcall(os.remove, content_path)
  pcall(os.remove, manifest_path)

  return wrap_result(result)
end

--- Unsquash selected hunks from parent back to working copy.
---@param filename string File path relative to repo root
---@param hunks table[] Selected hunks to unsquash
---@param diff table Full file diff (from parent's perspective)
---@param opts? {partial?: boolean, sel_from?: number, sel_to?: number}
---@return {success: boolean, error: string|nil}
function M.unsquash_hunks(filename, hunks, diff, opts)
  opts = opts or {}

  -- For unsquash, we're moving hunks from @- into @.
  -- Read the grandparent content (what @- was based on)
  local gp_result = jj.file.show.revision("@--").args(filename).call({ ignore_error = true })
  local before = gp_result.code == 0 and gp_result.stdout or {}

  -- Apply selected hunks to get patched content (content after removing selected hunks from @-)
  local patched
  if opts.partial and opts.sel_from and opts.sel_to and #hunks == 1 then
    patched = M.apply_partial_hunk(before, hunks[1], opts.sel_from, opts.sel_to)
  else
    patched = M.apply_selected_hunks(before, hunks)
  end

  -- Write patched content to tempfile
  local content_path = vim.fn.tempname()
  vim.fn.writefile(patched, content_path)

  -- Build and write manifest
  local manifest = {
    mode = "include",
    files = {
      [filename] = build_manifest_entry(content_path),
    },
  }
  local manifest_path = write_manifest(manifest)

  local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""
  local tool_path = vim.fn.fnamemodify(script_dir .. "../../../../scripts/maju-diff-tool", ":p")

  -- Call jj squash --from @- --into @ with the diff tool
  local result = jj.squash.from("@-").into("@").tool(tool_path).env({ MAJU_MANIFEST = manifest_path }).files(filename).call({ ignore_error = true })

  -- Clean up tempfiles
  pcall(os.remove, content_path)
  pcall(os.remove, manifest_path)

  return wrap_result(result)
end

--- Restore (discard) selected hunks from working copy by writing directly to disk.
---@param root string Repository root path
---@param filename string File path relative to repo root
---@param hunks table[] Selected hunks to restore
---@param diff table Full file diff
---@param opts? {partial?: boolean, sel_from?: number, sel_to?: number}
---@return {success: boolean, error: string|nil}
function M.restore_hunks(root, filename, hunks, diff, opts)
  opts = opts or {}
  local filepath = root .. "/" .. filename

  -- Handle special cases for file modes
  if diff and diff.kind == "new file" then
    -- New file: discarding all hunks = delete the file
    local ok, err = os.remove(filepath)
    if ok then
      return { success = true }
    else
      return { success = false, error = err }
    end
  end

  if diff and diff.kind == "deleted file" then
    -- Deleted file: restoring = read from @- and write to disk
    local parent_result = jj.file.show.revision("@-").args(filename).call({ ignore_error = true })
    if parent_result.code ~= 0 then
      return { success = false, error = "Failed to read parent file content" }
    end
    -- Ensure directory exists
    local dir = vim.fn.fnamemodify(filepath, ":h")
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile(parent_result.stdout, filepath)
    return { success = true }
  end

  -- Read current disk file
  local disk_lines = vim.fn.readfile(filepath)

  -- Sort hunks by disk_from descending to avoid offset shifts
  local sorted = vim.deepcopy(hunks)
  table.sort(sorted, function(a, b)
    return a.disk_from > b.disk_from
  end)

  for _, hunk in ipairs(sorted) do
    local before
    if opts.partial and opts.sel_from and opts.sel_to then
      -- Partial restore: build replacement with partial selection
      before = {}
      for i, line in ipairs(hunk.lines) do
        local c = line:sub(1, 1)
        local idx = i - 1
        local content = line:sub(2)

        if c == " " then
          table.insert(before, content)
        elseif idx >= opts.sel_from and idx <= opts.sel_to then
          -- Inside selection: revert changes
          if c == "-" then
            table.insert(before, content)
          end
          -- "+" lines: exclude (undo the addition)
        else
          -- Outside selection: keep working copy state
          if c == "+" then
            table.insert(before, content)
          end
          -- "-" lines: exclude (keep them removed)
        end
      end
    else
      before = hunk_before_lines(hunk.lines)
    end

    local from = hunk.disk_from
    local len = hunk.disk_len

    for _ = 1, len do
      table.remove(disk_lines, from)
    end
    for i, line in ipairs(before) do
      table.insert(disk_lines, from + i - 1, line)
    end
  end

  vim.fn.writefile(disk_lines, filepath)
  return { success = true }
end

---@param opts? {revision?: string, from?: string, into?: string, files?: string[], interactive?: boolean, tool?: string}
---@return {success: boolean, error: string|nil}
function M.squash(opts)
  opts = opts or {}
  local cmd = jj.squash
  if opts.revision then
    cmd = cmd.revision(opts.revision)
  end
  if opts.from then
    cmd = cmd.from(opts.from)
  end
  if opts.into then
    cmd = cmd.into(opts.into)
  end
  if opts.interactive then
    cmd = cmd.interactive
  end
  if opts.tool then
    cmd = cmd.tool(opts.tool)
  end
  if opts.files and #opts.files > 0 then
    cmd = cmd.files(unpack(opts.files))
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param files string[]
---@return {success: boolean, error: string|nil}
function M.squash_files(files)
  return M.squash({ files = files })
end

---@param opts? {interactive?: boolean}
---@return {success: boolean, error: string|nil}
function M.unsquash(opts)
  opts = opts or {}
  local cmd = jj.squash.from("@-").into("@")
  if opts.interactive then
    cmd = cmd.interactive
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param files string[]
---@return {success: boolean, error: string|nil}
function M.unsquash_files(files)
  return M.squash({ from = "@-", into = "@", files = files })
end

---@param opts? {from?: string, to?: string, revision?: string, files?: string[]}
---@return {success: boolean, error: string|nil}
function M.restore(opts)
  opts = opts or {}
  local cmd = jj.restore
  if opts.from then
    cmd = cmd.from(opts.from)
  end
  if opts.to then
    cmd = cmd.to(opts.to)
  end
  if opts.revision then
    cmd = cmd.revision(opts.revision)
  end
  if opts.files and #opts.files > 0 then
    cmd = cmd.files(unpack(opts.files))
  end
  return wrap_result(cmd.call({ ignore_error = true }))
end

---@param files string[]
---@return {success: boolean, error: string|nil}
function M.restore_files(files)
  return M.restore({ files = files })
end

return M
