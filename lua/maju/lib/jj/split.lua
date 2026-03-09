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

---@param opts? {revision?: string}
---@return string[] cmd_args Command arguments for terminal execution
function M.build_interactive_cmd(opts)
  opts = opts or {}
  local cmd = { "jj", "--no-pager", "split", "-i" }
  if opts.revision then
    table.insert(cmd, "-r")
    table.insert(cmd, opts.revision)
  end
  return cmd
end

---@param revision string
---@param files string[]
---@return {success: boolean, error: string|nil}
function M.split_by_files(revision, files)
  if #files == 0 then
    return { success = false, error = "No files selected" }
  end

  -- Write a manifest that includes only the selected files
  local manifest = { mode = "include", files = {} }
  for _, f in ipairs(files) do
    manifest.files[f] = { action = "take" }
  end

  local manifest_path = vim.fn.tempname() .. ".json"
  local json = vim.json.encode(manifest)
  vim.fn.writefile({ json }, manifest_path)

  local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""
  local tool_path = vim.fn.fnamemodify(script_dir .. "../../../../scripts/maju-diff-tool", ":p")

  local cmd = jj.split.revision(revision).tool(tool_path).env({ MAJU_MANIFEST = manifest_path })
  local result = cmd.call({ ignore_error = true })

  pcall(os.remove, manifest_path)

  return wrap_result(result)
end

---@param revision string
---@return string[]
function M.get_files(revision)
  local result = jj.diff.name_only.revision(revision).call({ ignore_error = true })
  if result.code == 0 then
    return vim.tbl_filter(function(line)
      return line ~= ""
    end, result.stdout)
  end
  return {}
end

return M
