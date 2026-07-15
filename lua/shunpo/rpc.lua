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
---@return boolean
function M.detach(addr)
  local ch = connect(addr)
  if not ch then
    return false
  end
  local ok = pcall(vim.rpcrequest, ch, "nvim_cmd", { cmd = "detach" }, {})
  close(ch)
  return ok
end

---@param addr string
---@return boolean
function M.detach_others(addr)
  local ch = connect(addr)
  if not ch then
    return false
  end
  local ok = pcall(vim.rpcrequest, ch, "nvim_input", string.char(27) .. ":%detach\r")
  close(ch)
  return ok
end

---@param addr string
---@param count integer? Passed through to Neovim's count-aware ZR command.
---@return boolean
function M.restart(addr, count)
  local ch = connect(addr)
  if not ch then
    return false
  end
  -- pass [range]ZR
  local keys = string.char(27) .. (count and count > 0 and tostring(count) or "") .. "ZR"
  local ok = pcall(vim.rpcnotify, ch, "nvim_input", keys)
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
