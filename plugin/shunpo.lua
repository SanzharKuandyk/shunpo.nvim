if vim.g.loaded_shunpo then
  return
end
vim.g.loaded_shunpo = true

vim.api.nvim_create_user_command("Shunpo", function()
  require("shunpo")
end, {
  desc = "Shunpo entry point",
})
