local M = {}

local config = require("shunpo.config")

local start_time = os.time()

---@type string?
local current_name = nil
---@type string?
local registered_servername = vim.v.startreason == "restart" and nil or vim.v.servername
local write_seq = 0
local shutting_down = false

---@return string?
local function published_servername()
  return registered_servername and registered_servername ~= "" and registered_servername or nil
end

---@return string?
function M.current_name()
  return current_name
end

---@return string
function M.dir()
  local dir = config.get().registry.dir or (vim.fn.stdpath("data") .. "/shunpo/instances")
  vim.fn.mkdir(dir, "p")
  return dir
end

---@return string
function M.self_path()
  return M.dir() .. "/" .. vim.fn.getpid() .. ".json"
end

---@param path string
---@return table?
local function read_entry(path)
  if not vim.uv.fs_stat(path) then
    return nil
  end
  local ok_lines, lines = pcall(vim.fn.readfile, path)
  if not ok_lines then
    return nil
  end
  local ok, entry = pcall(vim.json.decode, table.concat(lines, ""))
  return ok and type(entry) == "table" and entry or nil
end

---@param entry table?
---@return boolean
local function process_alive(entry)
  return type(entry) == "table" and type(entry.pid) == "number" and vim.uv.kill(entry.pid, 0) == 0
end

---@param path string
---@param entry table
---@return boolean
local function atomic_write(path, entry)
  write_seq = write_seq + 1
  local tmp = string.format("%s.%d.%d.tmp", path, vim.fn.getpid(), write_seq)
  if not pcall(vim.fn.writefile, { vim.json.encode(entry) }, tmp) then
    return false
  end
  vim.uv.fs_unlink(path)
  if not vim.uv.fs_rename(tmp, path) then
    vim.uv.fs_unlink(tmp)
    return false
  end
  return true
end

function M.write_self()
  if shutting_down then
    return
  end
  local servername = published_servername()
  if not servername then
    return
  end
  local path = M.self_path()
  local existing = read_entry(path)
  local cwd = vim.fn.getcwd(-1, -1)
  local name = cwd
  local pinned = false
  if
    existing
    and existing.name_pinned
    and type(existing.name) == "string"
    and existing.name ~= ""
  then
    name = existing.name
    pinned = true
  end

  local entry = {
    pid = vim.fn.getpid(),
    servername = servername,
    name = name,
    name_pinned = pinned,
    start_time = start_time,
    updated_at = os.time(),
    has_ui = #vim.api.nvim_list_uis() > 0,
    meta = {
      tabs = #vim.api.nvim_list_tabpages(),
      bufs = #vim.fn.getbufinfo({ buflisted = 1 }),
      cwd = cwd,
    },
    nvim_version = vim.version(),
  }
  if atomic_write(path, entry) then
    current_name = entry.name
  end
end

function M.start()
  shutting_down = false
  vim.schedule(M.register)
end

function M.register()
  require("shunpo.restart").resolve(function(servername)
    if shutting_down then
      return
    end
    registered_servername = servername
    M.write_self()
  end)
end

function M.stop()
  shutting_down = true
  require("shunpo.restart").stop()
end

---@param entry table
---@param name string
---@return boolean
function M.rename(entry, name)
  if type(entry) ~= "table" or not entry._path then
    return false
  end
  local current = read_entry(entry._path)
  if not current or current.pid ~= entry.pid then
    return false
  end
  current.name = name
  current.name_pinned = true
  if not atomic_write(entry._path, current) then
    return false
  end
  if current.pid == vim.fn.getpid() then
    current_name = name
  end
  return true
end

function M.remove_self()
  M.stop()
  vim.uv.fs_unlink(M.self_path())
end

---@param prune_stale boolean?
---@return table[]
function M.scan(prune_stale)
  local entries = {}
  local handle = vim.uv.fs_scandir(M.dir())
  if not handle then
    return entries
  end
  while true do
    local name = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if name:match("^%d+%.json$") then
      local path = M.dir() .. "/" .. name
      local entry = read_entry(path)
      local alive = process_alive(entry)
      if entry and (alive or prune_stale == false) then
        entry._path = path
        entry._meta = entry.meta
        entries[#entries + 1] = entry
      else
        vim.uv.fs_unlink(path)
      end
    elseif name:match("%.json$") then
      -- Remove entries from the short-lived address-keyed registry format.
      vim.uv.fs_unlink(M.dir() .. "/" .. name)
    end
  end
  return entries
end

---@param entries table[]
---@return table[]
function M.prune(entries)
  return vim.tbl_filter(process_alive, entries)
end

return M
