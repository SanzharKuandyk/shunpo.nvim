local M = {}

local config = require("shunpo.config")

local start_time = os.time()

---@type string?
local current_name = nil

---@return string?
function M.current_name()
  return current_name
end

---@return string
function M.dir()
  local d = config.get().registry.dir or (vim.fn.stdpath("data") .. "/shunpo/instances")
  vim.fn.mkdir(d, "p")
  return d
end

---@return string
function M.self_path()
  return M.dir() .. "/" .. vim.fn.getpid() .. ".json"
end

---@param path string
---@return string?
local function read_existing_name(path)
  if not vim.uv.fs_stat(path) then
    return nil
  end
  local ok_lines, lines = pcall(vim.fn.readfile, path)
  if not ok_lines then
    return nil
  end
  local ok, existing = pcall(vim.json.decode, table.concat(lines, ""))
  if
    ok
    and type(existing) == "table"
    and type(existing.name) == "string"
    and existing.name ~= ""
  then
    return existing.name
  end
  return nil
end

---@param path string
---@param entry table
local function atomic_write(path, entry)
  local json = vim.json.encode(entry)
  local tmp = path .. ".tmp"
  vim.fn.writefile({ json }, tmp)
  vim.uv.fs_unlink(path)
  vim.uv.fs_rename(tmp, path)
end

---@return string?
local function consume_restart_handoff()
  local raw = vim.env.SHUNPO_RESTART_FROM
  vim.env.SHUNPO_RESTART_FROM = nil
  local old_pid = tonumber(raw or "")
  if not old_pid then
    return nil
  end
  local old_path = M.dir() .. "/" .. old_pid .. ".json"
  local name = read_existing_name(old_path)
  vim.uv.fs_unlink(old_path)
  return name
end

function M.write_self()
  if vim.v.servername == "" then
    return
  end
  local path = M.self_path()
  local name = read_existing_name(path) or consume_restart_handoff() or vim.fn.getcwd(-1, -1)
  local entry = {
    pid = vim.fn.getpid(),
    servername = vim.v.servername,
    name = name,
    argf = (vim.fn.exists("v:argf") == 1 and vim.v.argf) or {},
    start_time = start_time,
    has_ui = #vim.api.nvim_list_uis() > 0,
    nvim_version = vim.version(),
  }
  atomic_write(path, entry)
  current_name = entry.name
end

---@param entry table
---@param name string
---@return boolean
function M.rename(entry, name)
  if type(entry) ~= "table" or not entry._path or not vim.uv.fs_stat(entry._path) then
    return false
  end
  entry.name = name
  local persisted = vim.deepcopy(entry)
  persisted._path = nil
  atomic_write(entry._path, persisted)
  if entry.pid == vim.fn.getpid() then
    current_name = name
  end
  return true
end

function M.remove_self()
  vim.uv.fs_unlink(M.self_path())
end

---@return table[]
function M.scan()
  local entries = {}
  local dir = M.dir()
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return entries
  end
  while true do
    local name = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if name:match("%.json$") and not name:match("%.tmp%.json$") then
      local path = dir .. "/" .. name
      local lines = vim.fn.readfile(path)
      local raw = table.concat(lines, "")
      local ok, entry = pcall(vim.json.decode, raw)
      if ok and type(entry) == "table" then
        entry._path = path
        table.insert(entries, entry)
      else
        vim.uv.fs_unlink(path)
      end
    end
  end
  return entries
end

---@param entries table[]
---@return table[]
function M.prune(entries)
  local rpc = require("shunpo.rpc")
  local alive = {}
  for _, entry in ipairs(entries) do
    if rpc.is_alive(entry) then
      table.insert(alive, entry)
    else
      vim.uv.fs_unlink(entry._path)
    end
  end
  return alive
end

return M
