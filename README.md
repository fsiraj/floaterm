# Floaterm

A beautiful toggleable floating window for managing terminal buffers within Neovim.

![floaterm-noborder](https://github.com/user-attachments/assets/8a51aeff-dcc5-477f-a282-9b48a1e5bf2b)

> A fork of [nvzone/floaterm](https://github.com/nvzone/floaterm): borderless-only, colorscheme-driven highlights (no base46/volt colors), smart sizing, live resize, and configurable global keymaps.

## Install

```lua
{
  "fsiraj/floaterm",
  dependencies = "nvzone/volt",
  opts = {
    mappings = { toggle = "<C-t>", send = "<Leader>r" },
  },
}
```

`:FloatermToggle` is always available; `mappings.toggle` / `mappings.send` register global keymaps in `setup()`.

## Default config

```lua
{
  -- <= 1 is a fraction of the editor, > 1 is absolute cells
  size = { h = 0.6, w = 0.7, max_h = nil, max_w = nil },

  -- global keymap lhs
  mappings = { toggle = nil, send = nil },

  -- terminal-list sidebar width, in columns
  sidebar_w = 20,

  -- HSL lightness shift from Normal bg (sidebar +, terminal -)
  contrast = 3,

   -- enter insert mode when focusing a terminal
  autoinsert = true,

  -- env vars (string values) applied to every terminal; per-terminal `env` merges on top
  env = { NO_FF = "1" },

  -- ms to wait before typing a persist terminal's cmd, useful to delay till prompt is ready
  delay = 0,

  -- terminals opened on first launch, list or function() -> list
  terminals = {
    -- may also specify `cmd` (string or function() -> string) and `env` (table)
    { name = "main" },
  },
}
```

The window recomputes its geometry on every open and debounces `VimResized`, so it always fits the current editor size.

## Mappings

**Sidebar:**

- <kbd>a</kbd> — add terminal · <kbd>e</kbd> — rename · <kbd>d</kbd> — delete
- any number — switch to terminal with that index

**Sidebar + terminal:**

- <kbd>Ctrl+h</kbd> / <kbd>Ctrl+l</kbd> — switch between sidebar and terminal
- <kbd>Ctrl+j</kbd> / <kbd>Ctrl+k</kbd> — cycle to next / prev terminal

**Configurable globals**:

- `mappings.toggle` — toggle the window (normal + terminal mode)
- `mappings.send` — prompt for a command and run it in a named terminal

## API

`require("floaterm")` exposes:

| Function             | Description                                               |
| -------------------- | --------------------------------------------------------- |
| `setup(opts)`        | Apply config and register keymaps/autocmds.               |
| `toggle()`           | Open or close the window.                                 |
| `open()` / `close()` | Open / close explicitly.                                  |
| `is_open()`          | Whether the window is open.                               |
| `send(cmd, opts)`    | Send `cmd` to a terminal; `opts = { name, persist, env }` |

```lua
require("floaterm").send("btop +t", { name = "btop" }) -- open/focus a "btop" terminal
require("floaterm").send("npm run dev", { name = "dev", persist = true }) -- stay at a live shell after it exits
```

## Highlights

Derived from your colorscheme and recomputed on open and `ColorScheme` (no base46/volt colors):

| Group                                             | Used for             |
| ------------------------------------------------- | -------------------- |
| `FloatermNormal` / `FloatermBorder`               | terminal window      |
| `FloatermSidebarNormal` / `FloatermSidebarBorder` | sidebar window       |
| `FloatermActive`                                  | active terminal name |
