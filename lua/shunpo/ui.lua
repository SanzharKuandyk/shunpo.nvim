local M = {}

local config = require("shunpo.config")
local registry = require("shunpo.registry")
local rpc = require("shunpo.rpc")

local state = {
  buf = nil,
  win = nil,
  rows = {},
}

---@param servername string
---@return string
local function addr_tail(servername)
  return servername:match("[^\\]+$") or servername
end

---@param start_time number
---@return string
local function format_age(start_time)
  local diff = os.time() - (start_time or os.time())
  if diff < 60 then
    return diff .. "s"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m"
  else
    return math.floor(diff / 3600) .. "h"
  end
end

---@param argf table?
---@return string
local function format_argf(argf)
  if not argf or type(argf) ~= "table" or #argf == 0 then
    return ""
  end
  local names = {}
  for _, p in ipairs(argf) do
    table.insert(names, vim.fn.fnamemodify(p, ":t"))
  end
  local joined = table.concat(names, " ")
  if #joined > 26 then
    joined = joined:sub(1, 23) .. "..."
  end
  return joined
end

---@param entries table[]
---@return string[]
local function render(entries)
  local lines = {
    string.format(
      "  %s  %-20s  %-26s  %-6s  %-22s  %s",
      " ",
      "CWD",
      "FILES",
      "T/B",
      "SERVER",
      "AGE"
    ),
    "  " .. string.rep("─", 89),
  }
  state.rows = {}

  if #entries == 0 then
    table.insert(lines, "  (no other instances)")
    return lines
  end

  for i, entry in ipairs(entries) do
    local live_cwd = (entry._meta and entry._meta.cwd) or entry.cwd or ""
    local cwd = vim.fn.fnamemodify(live_cwd, ":t")
    if cwd == "" then
      cwd = live_cwd
    end
    if #cwd > 18 then
      cwd = cwd:sub(1, 15) .. "..."
    end

    local files = format_argf(entry.argf)
    local tabs_bufs = entry._meta and (entry._meta.tabs .. "/" .. entry._meta.bufs) or "?"
    local tail = addr_tail(entry.servername or "")
    if #tail > 20 then
      tail = tail:sub(1, 17) .. "..."
    end
    local age = format_age(entry.start_time)
    local ui_icon = entry.has_ui and "●" or "○"

    local line = string.format(
      "  %s  %-20s  %-26s  %-6s  %-22s  %s",
      ui_icon,
      cwd,
      files,
      tabs_bufs,
      tail,
      age
    )
    table.insert(lines, line)
    state.rows[i + 2] = entry
  end

  return lines
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.rows = {}
end

---@return table?
local function get_entry()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.rows[row]
end

---@param entry table
local function do_swap(entry)
  if not entry then
    return
  end
  local cfg = config.get()
  local cmd = (cfg.swap.kill_on_no_ui and "connect! " or "connect ")
    .. vim.fn.fnameescape(entry.servername)
  close()
  vim.cmd(cmd)
end

---@param entry table
local function do_kill(entry)
  if not entry then
    return
  end
  rpc.kill(entry.servername)
  M.open()
end

---@param cfg ShunpoConfig
local function set_keymaps(cfg)
  local km = cfg.keymaps
  local opts = { nowait = true, silent = true, noremap = true, buffer = state.buf }

  vim.keymap.set("n", km.swap, function()
    do_swap(get_entry())
  end, opts)

  vim.keymap.set("n", km.detach_self, function()
    close()
    vim.cmd("detach")
  end, opts)

  vim.keymap.set("n", km.kill_remote, function()
    do_kill(get_entry())
  end, opts)

  vim.keymap.set("n", km.refresh, function()
    M.open()
  end, opts)

  for _, key in ipairs(km.close) do
    vim.keymap.set("n", key, close, opts)
  end
end

function M.open()
  local cfg = config.get()
  close()

  local entries = registry.scan()

  if cfg.list.prune_on_open then
    entries = registry.prune(entries)
  end

  if not cfg.list.include_self then
    local self_pid = vim.fn.getpid()
    local filtered = {}
    for _, e in ipairs(entries) do
      if e.pid ~= self_pid then
        table.insert(filtered, e)
      end
    end
    entries = filtered
  end

  if cfg.list.fetch_meta then
    for _, entry in ipairs(entries) do
      entry._meta = rpc.fetch_meta(entry.servername)
    end
  end

  local lines = render(entries)

  local ui_list = vim.api.nvim_list_uis()
  local ui_info = ui_list[1] or { width = 80, height = 24 }
  local width = math.floor(ui_info.width * cfg.window.width)
  local max_height = math.floor(ui_info.height * cfg.window.height)
  local height = math.max(math.min(#lines, max_height), 3)
  local row = math.floor((ui_info.height - height) / 2)
  local col = math.floor((ui_info.width - width) / 2)

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
  vim.api.nvim_set_option_value("filetype", "shunpo", { buf = state.buf })

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = cfg.window.border,
    title = cfg.window.title,
    title_pos = "center",
    style = "minimal",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = state.win })

  local start_row = #entries > 0 and 3 or 1
  vim.api.nvim_win_set_cursor(state.win, { start_row, 0 })

  set_keymaps(cfg)
end

return M
