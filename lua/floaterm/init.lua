local M = {}
local api = vim.api
local utils = require('floaterm.utils')
local state = require('floaterm.state')
local volt = require('volt')
local voltui = require('volt.ui')

local sidebar_w = 20

-- Debounce timer for VimResized so we only reopen once resizing settles
local resize_timer
local resize_debounce = 100

-- Numbered glyphs shown next to each terminal in the sidebar
local num_icons = {
   '󰎡',
   '󰎤',
   '󰎧',
   '󰎪',
   '󰎭',
   '󰎱',
   '󰎳',
   '󰎶',
   '󰎹',
   '󰎼',
}
-- ┌──────────────────────────────────────────────────────────────────────┐
-- │                          Sidebar (volt UI)                           │
-- └──────────────────────────────────────────────────────────────────────┘

-- volt `lines` function: the terminal list plus the help footer
local function sidebar_lines()
   local lines = {}

   for i, v in ipairs(state.terminals) do
      local label = '  ' .. (v.name or 'term')
      local hl = state.buf == v.buf and 'ExGreen' or 'Comment'
      local actions = { click = function() utils.switch_buf(v.buf) end }
      local line = { { label, hl, actions }, { '_pad_' }, { num_icons[i] or tostring(i), hl } }
      table.insert(lines, voltui.hpad(line, 18))
   end

   local empty_lines_to_fill = state.h - #lines - 3
   for _ = 1, empty_lines_to_fill, 1 do
      table.insert(lines, {})
   end

   table.insert(lines, { { 'a - add', 'comment' } })
   table.insert(lines, { { 'e - edit', 'comment' } })
   table.insert(lines, { { 'd - delete', 'comment' } })

   return lines
end

-- Buffer-local keymaps for the sidebar window
local function set_sidebar_keymaps()
   local map = vim.keymap.set
   local fapi = require('floaterm.api')
   local opts = { buffer = state.sidebuf }

   map('n', 'e', fapi.edit_name, opts)
   map('n', 'a', fapi.new_term, opts)
   map('n', 'd', fapi.delete_term, opts)
   map('n', '<C-l>', fapi.switch_wins, opts)
   map('n', '<C-h>', fapi.switch_wins, opts)
   map('n', '<C-j>', function() fapi.cycle_term_bufs('next') end, opts)
   map('n', '<C-k>', function() fapi.cycle_term_bufs('prev') end, opts)
end

-- ┌──────────────────────────────────────────────────────────────────────┐
-- │                              Public API                              │
-- └──────────────────────────────────────────────────────────────────────┘

M.setup = function(opts)
   state.config = vim.tbl_deep_extend('force', state.config, opts or {})

   local maps = state.config.mappings
   if maps.toggle then vim.keymap.set({ 'n', 't' }, maps.toggle, M.toggle, { desc = 'Floaterm: Toggle' }) end
   if maps.send then vim.keymap.set('n', maps.send, function() M.send() end, { desc = 'Floaterm: Run command' }) end
end

M.is_open = function() return state.volt_set == true end

-- Switch to the terminal named `name` (creating it with `cmd` if absent), opening the UI first.
-- Called with no `cmd`, prompts for one.
M.send = function(cmd, name)
   if not cmd then
      vim.ui.input({ prompt = 'cmd: ' }, function(input)
         if input and input ~= '' then M.send(input) end
      end)
      return
   end
   name = name or cmd
   if not M.is_open() then M.open() end
   local term = utils.get_term_by_key(name, 'name')
   if term then
      utils.switch_buf(term[2].buf)
   else
      require('floaterm.api').new_term({ cmd = cmd, name = name })
   end
end

M.open = function()
   state.volt_set = true
   state.sidebuf = state.sidebuf or api.nvim_create_buf(false, true)
   state.prev_win_focussed = api.nvim_get_current_win()

   local conf = state.config
   local usr_terms = type(conf.terminals) == 'table' and conf.terminals or conf.terminals()
   state.terminals = state.terminals or vim.tbl_deep_extend('force', {}, usr_terms)

   utils.gen_term_bufs()
   state.buf = state.buf or state.terminals[1].buf

   -- Geometry (recomputed every open so it adapts to editor resizes)
   state.h = utils.resolve_dim(conf.size.h, vim.o.lines, conf.size.max_h)
   state.w = utils.resolve_dim(conf.size.w, vim.o.columns, conf.size.max_w)

   local pos_row = (vim.o.lines / 2 - state.h / 2) - 1
   local pos_col = (vim.o.columns / 2 - state.w / 2)

   local sidebar_win_opts = {
      row = pos_row,
      col = pos_col,
      width = sidebar_w,
      height = state.h,
      relative = 'editor',
      style = 'minimal',
      border = 'single',
      zindex = 100,
   }

   state.sidewin = api.nvim_open_win(state.sidebuf, true, sidebar_win_opts)

   -- A single {char, hl} entry repeats on all sides: 1-cell blank padding, no visible line
   local term_border = { { ' ', 'exdarkborder' } }

   state.term_win_opts = {
      row = -1,
      col = sidebar_w + 1,
      win = state.sidewin,
      width = state.w - sidebar_w,
      height = state.h,
      relative = 'win',
      style = 'minimal',
      border = term_border,
      zindex = 100,
   }

   api.nvim_win_set_hl_ns(state.sidewin, state.ns)

   api.nvim_set_hl(state.ns, 'floatBorder', { link = 'exblack2border' })
   api.nvim_set_hl(state.ns, 'Normal', { link = 'exblack2bg' })

   volt.gen_data({
      { buf = state.sidebuf, ns = state.ns, layout = { { lines = sidebar_lines, name = 'bufs' } }, xpad = 1 },
   })

   api.nvim_set_option_value('modifiable', true, { buf = state.sidebuf })

   volt.run(state.sidebuf, { h = sidebar_win_opts.height, w = sidebar_win_opts.width })

   state.win = api.nvim_open_win(state.buf, true, state.term_win_opts)

   utils.set_termwin_hl()
   utils.switch_buf(state.buf)

   set_sidebar_keymaps()

   vim.bo[state.sidebuf].ft = 'FloatermSidebar'

   local grp = api.nvim_create_augroup('FloatermAu', { clear = true })

   api.nvim_create_autocmd('WinClosed', {
      group = grp,
      callback = function(args)
         vim.schedule(function()
            if M.is_open() and utils.get_term_by_key(args.buf) then require('floaterm.api').delete_term(args.buf) end
         end)
      end,
   })

   -- Recompute geometry on editor resize by reopening (preserves terminal buffers).
   -- The reopen is deferred a tick so the close's scheduled WinClosed handler runs
   -- (and skips delete_term) before volt_set is true again.
   api.nvim_create_autocmd('VimResized', {
      group = grp,
      callback = function()
         if not M.is_open() then return end
         resize_timer = resize_timer or assert(vim.uv.new_timer())
         resize_timer:stop()
         resize_timer:start(
            resize_debounce,
            0,
            vim.schedule_wrap(function()
               if not M.is_open() then return end
               M.close()
               vim.schedule(M.open)
            end)
         )
      end,
   })
end

M.close = function()
   api.nvim_win_close(state.win, false)
   api.nvim_win_close(state.sidewin, false)
   state.volt_set = false
   api.nvim_set_current_win(state.prev_win_focussed)
end

M.toggle = function()
   if M.is_open() then
      M.close()
   else
      M.open()
   end
end

return M
