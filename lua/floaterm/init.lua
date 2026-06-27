local M = {}
local api = vim.api
local utils = require('floaterm.utils')
local state = require('floaterm.state')

-- ┌──────────────────────────────────────────────────────────────────────┐
-- │                              Public API                              │
-- └──────────────────────────────────────────────────────────────────────┘

M.setup = function(opts)
   state.config = vim.tbl_deep_extend('force', state.config, opts or {})

   local maps = state.config.mappings
   if maps.toggle then vim.keymap.set({ 'n', 't' }, maps.toggle, M.toggle, { desc = 'Floaterm: Toggle' }) end
   if maps.send then vim.keymap.set('n', maps.send, function() M.send() end, { desc = 'Floaterm: Run command' }) end

   utils.set_highlights()
   utils.set_autocmds()
end

M.is_open = function() return state.is_open == true end

M.send = function(cmd, opts)
   if not cmd then
      vim.ui.input({ prompt = 'cmd: ' }, function(input)
         if input and input ~= '' then M.send(input) end
      end)
      return
   end
   opts = opts or {}
   local name = opts.name or cmd
   if not M.is_open() then M.open() end
   local term = utils.get_term_by_key(name, 'name')
   if term then
      utils.switch_buf(term[2].buf)
   else
      require('floaterm.api').new_term({ cmd = cmd, name = name, persist = opts.persist, env = opts.env })
   end
end

M.open = function()
   state.is_open = true
   state.sidebuf = state.sidebuf or api.nvim_create_buf(false, true)
   state.prev_win_focussed = api.nvim_get_current_win()

   local conf = state.config
   local usr_terms = type(conf.terminals) == 'table' and conf.terminals or conf.terminals()
   state.terminals = state.terminals or vim.tbl_deep_extend('force', {}, usr_terms)

   utils.gen_term_bufs()
   state.buf = state.buf or state.terminals[1].buf

   state.h = utils.resolve_dim(conf.size.h, vim.o.lines, conf.size.max_h)
   state.w = utils.resolve_dim(conf.size.w, vim.o.columns, conf.size.max_w)

   local pos_row = (vim.o.lines / 2 - state.h / 2)
   local pos_col = (vim.o.columns / 2 - state.w / 2)

   utils.render_sidebar(pos_row, pos_col)
   utils.render_terminal()
   utils.switch_buf(state.buf)
end

M.close = function()
   if api.nvim_win_is_valid(state.win) then api.nvim_win_close(state.win, false) end
   if api.nvim_win_is_valid(state.sidewin) then api.nvim_win_close(state.sidewin, false) end
   state.is_open = false
   if api.nvim_win_is_valid(state.prev_win_focussed) then api.nvim_set_current_win(state.prev_win_focussed) end
end

M.toggle = function()
   if M.is_open() then
      M.close()
   else
      M.open()
   end
end

return M
