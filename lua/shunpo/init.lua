local M = {}

---@class ShunpoConfig
local defaults = {
  -- TODO: add options
}

M.config = {}

---@param opts ShunpoConfig?
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return M
