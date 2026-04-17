local M = {}

local config = require("shunpo.config")
local registry = require("shunpo.registry")
local rpc = require("shunpo.rpc")

local state = {
  buf = nil,
  win = nil,
  rows = {},
  self_row = nil,
  timer = nil,
}

local ns = vim.api.nvim_create_namespace("shunpo")
vim.api.nvim_set_hl(0, "ShunpoSelf", { link = "Special", default = true })

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

---@param raw string
---@param max number
---@return string
local function format_name(raw, max)
  if #raw <= max then
    return raw
  end
  if raw:find("[/\\]") then
    local base = vim.fn.fnamemodify(raw, ":t")
    if base == "" then
      base = raw
    end
    local out = base .. "/"
    if #out > max then
      out = out:sub(1, max - 3) .. "..."
    end
    return out
  end
  return raw:sub(1, max - 3) .. "..."
end

---@param entry table
---@return string
local function format_status(entry)
  if entry.has_ui then
    return "attached"
  end
  return "detached"
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

local ROW_FMT = "  %s  %-18s  %-10s  %-20s  %-5s  %-18s  %s"

---@param s string
---@param w number
---@return string
local function pad(s, w)
  local n = vim.fn.strdisplaywidth(s)
  if n >= w then
    return s
  end
  return s .. string.rep(" ", w - n)
end

---@param entries table[]
---@param width number
---@return string[]
local function render(entries, width)
  local header = string.format(ROW_FMT, " ", "NAME", "STATUS", "FILES", "T/B", "SERVER", "AGE")
  local lines = {
    pad(header, width),
    "  " .. string.rep("─", math.max(0, width - 2)),
  }
  state.rows = {}

  if #entries == 0 then
    table.insert(lines, pad("  (no instances)", width))
    return lines
  end

  for i, entry in ipairs(entries) do
    local raw_name = entry.name
    if not raw_name or raw_name == "" then
      raw_name = (entry._meta and entry._meta.cwd) or ""
    end
    local name = format_name(raw_name, 18)

    local status = format_status(entry)
    local files = format_argf(entry.argf)
    local tabs_bufs = entry._meta and (entry._meta.tabs .. "/" .. entry._meta.bufs) or "?"
    local tail = addr_tail(entry.servername or "")
    if #tail > 18 then
      tail = tail:sub(1, 15) .. "..."
    end
    local age = format_age(entry.start_time)
    local icon = entry.has_ui and "●" or "○"

    local row = string.format(ROW_FMT, icon, name, status, files, tabs_bufs, tail, age)
    table.insert(lines, pad(row, width))
    state.rows[i + 2] = entry
  end

  return lines
end

local function stop_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

local function close()
  stop_timer()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.rows = {}
  state.self_row = nil
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

---@param entry table
local function do_restart(entry)
  if not entry then
    return
  end
  rpc.restart(entry.servername)
  vim.defer_fn(function()
    M.open()
  end, 300)
end

---@param entry table
local function do_rename(entry)
  if not entry then
    return
  end
  local current = entry.name or ""
  close()
  vim.ui.input({ prompt = "shunpo rename: ", default = current }, function(input)
    if input == nil then
      M.open()
      return
    end
    local name = vim.trim(input)
    if name ~= "" then
      registry.rename(entry, name)
    end
    M.open()
  end)
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

  vim.keymap.set("n", km.rename, function()
    do_rename(get_entry())
  end, opts)

  vim.keymap.set("n", km.restart, function()
    do_restart(get_entry())
  end, opts)

  for _, key in ipairs(km.close) do
    vim.keymap.set("n", key, close, opts)
  end
end

---@param cfg ShunpoConfig
---@return table[], number
local function collect_entries(cfg)
  local self_pid = vim.fn.getpid()
  local entries = registry.scan()

  if cfg.list.prune_on_open then
    entries = registry.prune(entries)
  end

  if not cfg.list.include_self then
    local filtered = {}
    for _, e in ipairs(entries) do
      if e.pid ~= self_pid then
        table.insert(filtered, e)
      end
    end
    entries = filtered
  end

  if cfg.list.detached_only then
    local filtered = {}
    for _, e in ipairs(entries) do
      if not e.has_ui then
        table.insert(filtered, e)
      end
    end
    entries = filtered
  end

  local self_idx
  for i, e in ipairs(entries) do
    if e.pid == self_pid then
      self_idx = i
      break
    end
  end
  if self_idx and self_idx ~= 1 then
    local s = table.remove(entries, self_idx)
    table.insert(entries, 1, s)
    self_idx = 1
  end

  if cfg.list.fetch_meta then
    for _, entry in ipairs(entries) do
      entry._meta = rpc.fetch_meta(entry.servername)
    end
  end

  return entries, (self_idx and 3) or nil
end

---@param entries table[]
---@param self_row number?
---@param width number
local function write_buf(entries, self_row, width)
  local lines = render(entries, width)
  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  if self_row then
    vim.api.nvim_buf_set_extmark(state.buf, ns, self_row - 1, 0, {
      line_hl_group = "ShunpoSelf",
    })
  end
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
  state.self_row = self_row
  return lines
end

---@param cfg ShunpoConfig
---@param line_count number
---@return table
local function compute_dims(cfg, line_count)
  local ui_list = vim.api.nvim_list_uis()
  local ui_info = ui_list[1] or { width = 80, height = 24 }
  local width = math.max(math.floor(ui_info.width * cfg.window.width), 40)
  local max_height = math.floor(ui_info.height * cfg.window.height)
  local height = math.max(math.min(line_count, max_height), 3)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui_info.height - height) / 2),
    col = math.floor((ui_info.width - width) / 2),
  }
end

---Refresh contents in place. Recomputes size so resized terminals stay correct.
---@param force boolean? skip normal-mode check when true (manual refresh)
local function refresh(force)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    stop_timer()
    return
  end
  if not force and vim.api.nvim_get_mode().mode ~= "n" then
    return
  end

  local cfg = config.get()
  local entries, self_row = collect_entries(cfg)
  local probe = render(entries, 1)
  local dims = compute_dims(cfg, #probe)

  vim.api.nvim_win_set_config(state.win, {
    relative = dims.relative,
    width = dims.width,
    height = dims.height,
    row = dims.row,
    col = dims.col,
  })

  write_buf(entries, self_row, dims.width)
end

function M.open()
  local cfg = config.get()

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    refresh(true)
    vim.api.nvim_set_current_win(state.win)
    return
  end

  close()

  local entries, self_row = collect_entries(cfg)
  local probe = render(entries, 1)
  local dims = compute_dims(cfg, #probe)

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
  vim.api.nvim_set_option_value("filetype", "shunpo", { buf = state.buf })

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = dims.relative,
    width = dims.width,
    height = dims.height,
    row = dims.row,
    col = dims.col,
    border = cfg.window.border,
    title = cfg.window.title,
    title_pos = "center",
    style = "minimal",
  })

  write_buf(entries, self_row, dims.width)
  vim.api.nvim_set_option_value("cursorline", true, { win = state.win })

  local start_row = #entries > 0 and 3 or 1
  vim.api.nvim_win_set_cursor(state.win, { start_row, 0 })

  local aug = vim.api.nvim_create_augroup("ShunpoUI", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = aug,
    callback = function()
      refresh(true)
    end,
  })

  set_keymaps(cfg)

  if cfg.list.autorefresh and cfg.list.autorefresh_period > 0 then
    state.timer = vim.uv.new_timer()
    state.timer:start(
      cfg.list.autorefresh_period,
      cfg.list.autorefresh_period,
      vim.schedule_wrap(function()
        refresh(false)
      end)
    )
  end
end

return M
