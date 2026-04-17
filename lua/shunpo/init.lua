local M = {}

local config = require("shunpo.config")

---@param opts ShunpoConfig?
function M.setup(opts)
  config.merge(opts)
end

function M.open()
  require("shunpo.ui").open()
end

---@param opts ShunpoLualineOpts?
---@return string
function M.lualine(opts)
  return require("shunpo.lualine").component(opts)
end

---@param dir 1|-1
function M.rotate(dir)
  local registry = require("shunpo.registry")
  local entries = registry.prune(registry.scan())
  if #entries == 0 then
    return
  end
  table.sort(entries, function(a, b)
    return (a.start_time or 0) < (b.start_time or 0)
  end)

  local self_pid = vim.fn.getpid()
  local idx
  for i, e in ipairs(entries) do
    if e.pid == self_pid then
      idx = i
      break
    end
  end

  local target
  if not idx then
    target = entries[1]
  else
    local n = #entries
    target = entries[((idx - 1 + dir) % n) + 1]
  end
  if not target or target.pid == self_pid then
    return
  end

  local cfg = config.get()
  local cmd = (cfg.swap.kill_on_no_ui and "connect! " or "connect ")
    .. vim.fn.fnameescape(target.servername)
  vim.cmd(cmd)
end

function M.next()
  M.rotate(1)
end

function M.prev()
  M.rotate(-1)
end

return M
