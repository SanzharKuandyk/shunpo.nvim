local M = {}

local function connect(addr)
  local ok, ch = pcall(vim.fn.sockconnect, "pipe", addr, { rpc = true })
  if ok and ch and ch > 0 then
    return ch
  end
  return nil
end

local function close(ch)
  pcall(vim.fn.chanclose, ch)
end

---@param entry table
---@return boolean
function M.is_alive(entry)
  local ch = connect(entry.servername)
  if ch then
    close(ch)
    return true
  end
  return false
end

---@param addr string
---@param ex_cmd table
---@return boolean
function M.remote_cmd(addr, ex_cmd)
  local ch = connect(addr)
  if not ch then
    return false
  end

  -- Fire-and-forget is fine for commands like :detach / :connect / :restart
  local ok = pcall(vim.rpcnotify, ch, "nvim_cmd", ex_cmd, {})
  close(ch)
  return ok
end

---@param addr string
---@return table?
function M.fetch_meta(addr)
  local ch = connect(addr)
  if not ch then
    return nil
  end

  local ok_tabs, tabs = pcall(vim.rpcrequest, ch, "nvim_list_tabpages")
  local ok_bufs, bufs =
    pcall(vim.rpcrequest, ch, "nvim_call_function", "getbufinfo", { { buflisted = 1 } })
  local ok_cwd, cwd = pcall(vim.rpcrequest, ch, "nvim_call_function", "getcwd", { -1, -1 })

  close(ch)

  if ok_tabs and ok_bufs and ok_cwd then
    return {
      tabs = #tabs,
      bufs = #bufs,
      cwd = cwd,
    }
  end

  return nil
end

---@param addr string
function M.detach(addr)
  return M.remote_cmd(addr, { cmd = "detach" })
end

---@param addr string
---@return boolean
function M.restart(addr)
  local ch = connect(addr)
  if not ch then
    return false
  end
  -- Windows nvim can't reuse the same --listen address on :restart (pipe not
  -- released in time). Hand off via old pid so the new process can adopt the
  -- name from the prior registry file. See neovim#38539.
  local code = [[
    vim.env.SHUNPO_RESTART_FROM = tostring(vim.fn.getpid())
    vim.cmd("restart")
  ]]
  local ok = pcall(vim.rpcnotify, ch, "nvim_exec_lua", code, {})
  close(ch)
  return ok
end

---@param addr string
---@param target string
function M.connect_ui(addr, target)
  return M.remote_cmd(addr, { cmd = "connect", args = { target } })
end

---@param addr string
function M.kill(addr)
  local ch = connect(addr)
  if not ch then
    return false
  end
  local ok = pcall(vim.rpcrequest, ch, "nvim_cmd", { cmd = "qall", bang = true }, {})
  close(ch)
  return ok
end

return M
