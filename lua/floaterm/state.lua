local M = {
   ns = vim.api.nvim_create_namespace('Floaterm'),
   terminals = nil,
   is_open = false,
   prev_win_focussed = 0,

   config = {
      size = {
         h = 0.7,
         w = 0.7,
         max_h = nil,
         max_w = nil,
      },
      mappings = {
         toggle = nil,
         send = nil,
      },
      sidebar_w = 20,
      contrast = 3,
      autoinsert = true,
      env = {},
      delay = 0,
      terminals = {
         { name = 'main' },
      },
   },
}

return M
