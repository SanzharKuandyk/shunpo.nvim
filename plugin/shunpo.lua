if vim.g.loaded_shunpo then
  return
end
vim.g.loaded_shunpo = true

vim.api.nvim_create_user_command("Shunpo", function()
  require("shunpo").open()
end, {
  desc = "Open shunpo instance list",
})

local group = vim.api.nvim_create_augroup("ShunpoRegistry", { clear = true })

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  callback = function()
    if require("shunpo.config").get().autocmds.register_on_vimenter then
      vim.schedule(require("shunpo.registry").write_self)
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    require("shunpo.registry").remove_self()
  end,
})

vim.api.nvim_create_autocmd("UIEnter", {
  group = group,
  callback = function()
    require("shunpo.registry").write_self()
  end,
})

vim.api.nvim_create_autocmd("UILeave", {
  group = group,
  callback = function()
    require("shunpo.registry").write_self()
  end,
})

vim.api.nvim_create_autocmd("DirChanged", {
  group = group,
  pattern = "global",
  callback = function()
    if require("shunpo.config").get().autocmds.update_on_dirchanged then
      require("shunpo.registry").write_self()
    end
  end,
})
