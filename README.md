<div align="center">
  <h1>shunpo.nvim ⚡</h1>
   <img src="shunpo.png" alt="Screenshot of shunpo.nvim"/>
</div>

Flash-step between running nvim instances. Detach here, reattach there.

Currently Windows only.

## Requirements

- Neovim v0.12.1+

## Install

### vim.pkg (Neovim 0.12+)

```lua
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

Hooks into nvim's built-in `:detach` / `:connect` / `:restart`.

| Command | Action |
|---|---|
| `:Shunpo` | Open instance list |
| `:ShunpoNext` | Swap UI to next instance |
| `:ShunpoPrev` | Swap UI to previous instance |

## List keymaps

| Key | Action |
|---|---|
| `<CR>` | Swap UI to instance |
| `d` | Detach current UI |
| `x` | Kill remote instance |
| `i` | Rename instance |
| `r` | Refresh list |
| `R` | Restart instance |
| `q` / `<Esc>` | Close |

## Lualine

```lua
lualine_c = {
  function()
    return require("shunpo").lualine({
      fallback = vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
    })
  end,
}
```

## Config

```lua
require("shunpo").setup({
  window = {
    width = 0.5,                      -- fraction of screen width
    height = 0.5,                     -- fraction of screen height
    border = "rounded",               -- any nvim_open_win border style
    title = " shunpo ",               -- float title
  },
  registry = {
    dir = nil,                        -- override instances dir (default: stdpath("data")/shunpo/instances)
  },
  list = {
    include_self = false,             -- show current instance in the list
    fetch_meta = true,                -- RPC each instance for tabs/bufs/cwd
    prune_on_open = true,             -- drop dead entries when opening the list
    -- detached_only = false,         -- hide attached instances (commented: off by default)
    autorefresh = true,               -- re-render list on a timer
    autorefresh_period = 3000,        -- refresh interval in ms
  },
  swap = {
    kill_on_no_ui = false,            -- :connect! — kill source server if it has no UIs left
  },
  keymaps = {
    swap = "<CR>",                    -- swap UI to the selected instance
    detach_self = "d",                -- :detach on self
    kill_remote = "x",                -- :qall! on selected instance
    rename = "i",                     -- rename selected instance (vim.ui.input)
    refresh = "r",                    -- rebuild list
    restart = "R",                    -- :restart on selected instance (preserves name)
    close = { "q", "<Esc>" },
    next = {},                        -- jump cursor to next row (unbound by default)
    prev = {},                        -- jump cursor to prev row (unbound by default)
  },
  autocmds = {
    register_on_vimenter = true,      -- write registry entry on VimEnter
    update_on_dirchanged = true,      -- refresh entry when cwd changes
  },
})
```
