local M = {}

local registry = require("shunpo.registry")

---@class ShunpoLualineOpts
---@field icon string?
---@field fallback string?
---@field basename boolean?

---@param opts ShunpoLualineOpts?
---@return string
function M.component(opts)
  opts = opts or {}
  local name = registry.current_name()
  if not name or name == "" then
    name = opts.fallback or ""
  end
  if name == "" then
    return ""
  end
  if opts.basename ~= false and name:find("[/\\]") then
    name = vim.fn.fnamemodify(name, ":t")
  end
  if opts.icon and opts.icon ~= "" then
    return opts.icon .. " " .. name
  end
  return name
end

return M
