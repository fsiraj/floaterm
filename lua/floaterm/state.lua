local M = {
  ns = vim.api.nvim_create_namespace "Floaterm",
  terminals = nil,
  is_open = false,
  prev_win_focussed = 0,

  config = {
    autoinsert = true,

    -- width of the terminal-list sidebar, in columns
    sidebar_w = 20,

    -- h/w: a value <= 1 is a fraction of the editor; a larger value is absolute cells.
    -- max_h/max_w: optional caps using the same semantics. nil = editor size.
    size = { h = 0.6, w = 0.7, max_h = nil, max_w = nil },

    -- toggle/send: optional global keymap lhs (e.g. "<C-t>") wired up in setup().
    mappings = { toggle = nil, send = nil },
    terminals = {
      { name = "main" },
    },
  },
}

return M
