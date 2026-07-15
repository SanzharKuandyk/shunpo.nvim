local M = {}

local poll_ms = 50
local timeout_ms = 30000

---@type uv.uv_timer_t?
local timer = nil

---@return string?
local function canonical_addr()
  local ok, server = pcall(require, "vim._core.server")
  local addr = ok and server.restart_canonical_addr or nil
  return type(addr) == "string" and addr ~= "" and addr or nil
end

---@param callback fun(addr: string)
function M.resolve(callback)
  local fallback = vim.v.servername
  local canonical = canonical_addr()
  if vim.v.startreason ~= "restart" then
    callback(fallback)
    return
  end
  if canonical and vim.v.servername == canonical then
    callback(canonical)
    return
  end

  -- Detached restarts never emit UIEnter, so publish the temporary server
  -- immediately and replace it with the canonical address after handoff.
  callback(fallback)
  if timer then
    return
  end

  local elapsed = 0
  timer = assert(vim.uv.new_timer())
  timer:start(
    poll_ms,
    poll_ms,
    vim.schedule_wrap(function()
      if not timer then
        return
      end
      elapsed = elapsed + poll_ms
      canonical = canonical_addr()
      -- v:servername changes when this process retires
      -- its bootstrap pipe and becomes the canonical server.
      if canonical and vim.v.servername == canonical then
        timer:stop()
        timer:close()
        timer = nil
        callback(canonical)
      elseif elapsed >= timeout_ms then
        timer:stop()
        timer:close()
        timer = nil
      end
    end)
  )
end

function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

return M
