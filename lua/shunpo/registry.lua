local M = {}

local config = require("shunpo.config")

local start_time = os.time()

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

function M.write_self()
  if vim.v.servername == "" then
    return
  end
  local entry = {
    pid = vim.fn.getpid(),
    servername = vim.v.servername,
    cwd = vim.fn.getcwd(-1, -1),
    argf = (vim.fn.exists("v:argf") == 1 and vim.v.argf) or {},
    start_time = start_time,
    has_ui = #vim.api.nvim_list_uis() > 0,
    nvim_version = vim.version(),
  }
  local json = vim.json.encode(entry)
  local path = M.self_path()
  local tmp = path .. ".tmp"
  vim.fn.writefile({ json }, tmp)
  vim.loop.fs_unlink(path)
  vim.loop.fs_rename(tmp, path)
end

function M.remove_self()
  vim.loop.fs_unlink(M.self_path())
end

---@return table[]
function M.scan()
  local entries = {}
  local dir = M.dir()
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return entries
  end
  while true do
    local name = vim.loop.fs_scandir_next(handle)
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
        vim.loop.fs_unlink(path)
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
      vim.loop.fs_unlink(entry._path)
    end
  end
  return alive
end

return M
