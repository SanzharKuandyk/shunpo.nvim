local M = {}

---@param entry table
---@return boolean
function M.is_alive(entry)
  local ok, ch = pcall(vim.fn.sockconnect, "pipe", entry.servername, { rpc = true })
  if ok and ch and ch > 0 then
    pcall(vim.fn.chanclose, ch)
    return true
  end
  return false
end

---@param addr string
---@param cmd string
function M.remote_exec(addr, cmd)
  local ok, ch = pcall(vim.fn.sockconnect, "pipe", addr, { rpc = true })
  if not (ok and ch and ch > 0) then
    return
  end
  pcall(vim.rpcnotify, ch, "nvim_command", cmd)
  pcall(vim.fn.chanclose, ch)
end

---@param addr string
---@return table?
function M.fetch_meta(addr)
  local ok, ch = pcall(vim.fn.sockconnect, "pipe", addr, { rpc = true })
  if not (ok and ch and ch > 0) then
    return nil
  end
  local meta_ok, result = pcall(
    vim.rpcrequest,
    ch,
    "nvim_exec_lua",
    "return {#vim.api.nvim_list_tabpages(), #vim.fn.getbufinfo({buflisted=1}), vim.fn.getcwd(-1,-1)}",
    {}
  )
  pcall(vim.fn.chanclose, ch)
  if meta_ok and type(result) == "table" then
    return { tabs = result[1], bufs = result[2], cwd = result[3] }
  end
  return nil
end

---@param addr string
function M.kill(addr)
  M.remote_exec(addr, "qall!")
end

return M
