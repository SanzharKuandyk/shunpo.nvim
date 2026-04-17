local M = {}

---@class ShunpoWindowConfig
---@field width number
---@field height number
---@field border string
---@field title string

---@class ShunpoRegistryConfig
---@field dir string?

---@class ShunpoListConfig
---@field include_self boolean
---@field fetch_meta boolean
---@field prune_on_open boolean
---@field detached_only boolean
---@field autorefresh boolean
---@field autorefresh_period number

---@class ShunpoSwapConfig
---@field kill_on_no_ui boolean

---@class ShunpoKeymapsConfig
---@field swap string
---@field detach_self string
---@field kill_remote string
---@field rename string
---@field refresh string
---@field restart string
---@field close string[]

---@class ShunpoAutocmdsConfig
---@field register_on_vimenter boolean
---@field update_on_dirchanged boolean

---@class ShunpoConfig
---@field window ShunpoWindowConfig
---@field registry ShunpoRegistryConfig
---@field list ShunpoListConfig
---@field swap ShunpoSwapConfig
---@field keymaps ShunpoKeymapsConfig
---@field autocmds ShunpoAutocmdsConfig

M.defaults = {
  window = {
    width = 0.5,
    height = 0.5,
    border = "rounded",
    title = " shunpo ",
  },
  registry = {
    dir = nil,
  },
  list = {
    include_self = false,
    fetch_meta = true,
    prune_on_open = true,
    -- Show detached (headless/background) instances only.
    -- detached_only = false,
    autorefresh = true,
    autorefresh_period = 3000,
  },
  swap = {
    kill_on_no_ui = false,
  },
  keymaps = {
    swap = "<CR>",
    detach_self = "d",
    kill_remote = "x",
    rename = "i",
    refresh = "r",
    -- :restart on the instance
    restart = "R",
    close = { "q", "<Esc>" },
    -- Go to next instance
    next = {},
    -- Go to prev instance
    prev = {},
  },
  autocmds = {
    register_on_vimenter = true,
    update_on_dirchanged = true,
  },
}

---@type ShunpoConfig?
M.current = nil

---@param opts ShunpoConfig?
---@return ShunpoConfig
function M.merge(opts)
  M.current = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  return M.current
end

---@return ShunpoConfig
function M.get()
  return M.current or M.defaults
end

return M
