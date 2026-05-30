local M = {
  ns = vim.api.nvim_create_namespace "Floaterm",
  terminals = nil,
  prev_win_focussed = 0,

  config = {
    autoinsert = true,

    -- h/w: a value <= 1 is a fraction of the editor; a larger value is absolute cells.
    -- max_h/max_w: optional caps using the same semantics. nil = editor size.
    size = { h = 0.6, w = 0.7, max_h = nil, max_w = nil },

    -- { row , col } or fn() returning the table
    position = nil,

    -- must be functions
    mappings = { sidebar = nil, term = nil },
    terminals = {
      { name = "main" },
    },
  },
}

return M
