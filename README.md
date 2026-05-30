# Floaterm

A beautiful toggleable floating window for managing terminal buffers within Neovim

![floaterm-noborder](https://github.com/user-attachments/assets/15e19849-69e6-432b-8fd9-7ffaad872e28)

## Install 

```lua 
{
    "nvzone/floaterm",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = "FloatermToggle",
}          
```

## Default config

```lua
 {
    -- h/w: a value <= 1 is a fraction of the editor; a larger value is absolute cells.
    -- max_h/max_w: optional caps using the same semantics (nil = editor size).
    -- e.g. { h = 0.9, w = 200, max_w = 0.9 } -> 200 cols, capped at 90% of the editor.
    size = { h = 0.6, w = 0.7, max_h = nil, max_w = nil },

    -- to use, make this func(buf)
    mappings = { sidebar = nil, term = nil},

    -- Default sets of terminals you'd like to open
    terminals = {
      { name = "main" },
      -- cmd can be function too
      { name = "main", cmd = "neofetch" },
      -- More terminals
    },
}
```

## Mappings

This are the mappings for sidebar 
- <kbd>a</kbd> -> add new terminal
- <kbd>e</kbd> -> edit terminal name
- <kbd>d</kbd> -> delete terminal
- Pressing any number within sidebar will switch to that terminal

These mappings work in both the sidebar and the terminal buffer:
- <kbd>Ctrl + h</kbd> / <kbd>Ctrl + l</kbd> -> Switch between sidebar and terminal
- <kbd>Ctrl + j</kbd> -> Cycle to next terminal
- <kbd>Ctrl + k</kbd> -> Cycle to prev terminal

> The default `volt` <kbd>q</kbd> / <kbd>Esc</kbd> / <kbd>Ctrl + t</kbd> mappings are removed so they don't interfere with terminal use.

Add new mapping

```lua 
  {
     mappings = {
       term = function(buf)
         vim.keymap.set({ "n", "t" }, "<C-p>", function()
           require("floaterm.api").cycle_term_bufs "prev"
         end, { buffer = buf })
       end,
     },
  },
```
