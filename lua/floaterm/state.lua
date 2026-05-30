local M = {
   ns = vim.api.nvim_create_namespace('Floaterm'),
   terminals = nil,
   is_open = false,
   prev_win_focussed = 0,

   config = {
      autoinsert = true,
      sidebar_w = 20,
      contrast = 3,
      size = {
         h = 0.6,
         w = 0.7,
         max_h = nil,
         max_w = nil,
      },
      mappings = {
         toggle = nil,
         send = nil,
      },
      terminals = {
         { name = 'main' },
      },
   },
}

return M
