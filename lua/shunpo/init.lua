local M = {}

local config = require("shunpo.config")

---@param opts ShunpoConfig?
function M.setup(opts)
  config.merge(opts)
end

function M.open()
  require("shunpo.ui").open()
end

return M
