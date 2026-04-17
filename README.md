# shunpo.nvim

Neovim instance manager. Detach, list, and swap between running nvim servers.
Windows-first, built on `:detach` / `:connect` from nvim master.

## Requirements

- Neovim v0.12.1+

## Install

### vim.pkg (Neovim 0.12+)

```lua
-- In your init.lua
vim.pkg.add("github:sanzharkuandyk/shunpo.nvim")

require("shunpo").setup({})
```

### Lazy
```lua
{
  "SanzharKuandyk/shunpo.nvim",
  opts = {},
}
```

## Commands

| Command | Action |
|---|---|
| `:Shunpo` | Open instance list |
| `:ShunpoDetach` | Detach current UI (server keeps running) |
| `:ShunpoConnect {addr}` | Move UI to another server (tab-complete servernames) |
| `:ShunpoConnect! {addr}` | Same, kill old server if no UIs remain |

## List keymaps

| Key | Action |
|---|---|
| `<CR>` | Swap UI to instance |
| `d` | Detach current UI |
| `x` | Kill remote instance |
| `r` | Refresh list |
| `q` / `<Esc>` | Close |

## Config

```lua
require("shunpo").setup({
  window = {
    width = 0.6,
    height = 0.5,
    border = "rounded",
    title = " shunpo ",
  },
  list = {
    include_self = false,
    fetch_meta = true,
    prune_on_open = true,
  },
  swap = {
    kill_on_no_ui = false,
  },
  keymaps = {
    swap = "<CR>",
    detach_self = "d",
    kill_remote = "x",
    refresh = "r",
    close = { "q", "<Esc>" },
  },
})
```
