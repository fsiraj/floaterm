local M = {}
local api = vim.api
local map = vim.keymap.set
local state = require('floaterm.state')
local volt_redraw = require('volt').redraw
local shell = vim.o.shell

-- Resolve a size dimension to absolute cells.
-- `value`/`max` <= 1 are fractions of `total`; larger values are absolute cells.
-- `max` is an optional cap (nil clamps to `total`).
M.resolve_dim = function(value, total, max)
   local n = value <= 1 and total * value or value
   local cap = max and (max <= 1 and total * max or max) or total
   return math.floor(math.min(n, cap))
end

M.convert_buf2term = function(cmd)
   if cmd then
      cmd = type(cmd) == 'function' and cmd() or cmd
      cmd = { shell, '-c', cmd .. '; ' .. shell }
   else
      cmd = { shell }
   end
   vim.fn.jobstart(cmd, { term = true })
end

M.new_term = function(opts)
   local defaults = {
      buf = api.nvim_create_buf(false, true),
      time = os.date('%H:%M'),
      name = 'term',
   }

   return vim.tbl_extend('force', defaults, opts or {})
end

M.add_keymap = function(key, buf)
   map('n', tostring(key), function() M.switch_buf(buf) end, { buffer = state.sidebuf })
end

M.gen_term_bufs = function()
   for i, _ in ipairs(state.terminals) do
      state.terminals[i] = vim.tbl_extend('force', M.new_term(), state.terminals[i])
      local buf = state.terminals[i].buf
      M.add_keymap(i, buf)
   end
end

M.set_termwin_hl = function() vim.wo[state.win].winhl = 'Normal:exdarkbg,floatBorder:exdarkborder' end

M.switch_buf = function(buf)
   state.buf = buf

   volt_redraw(state.sidebuf, 'bufs')

   if not api.nvim_win_is_valid(state.win) then
      state.win = api.nvim_open_win(state.buf, true, state.term_win_opts)
      M.set_termwin_hl()
   end

   api.nvim_set_current_win(state.win)
   api.nvim_set_current_buf(buf)

   local details = vim.tbl_filter(function(x) return x.buf == buf end, state.terminals)

   if vim.bo[buf].buftype ~= 'terminal' then
      vim.bo[buf].ft = 'Floaterm'
      M.convert_buf2term(details[1].cmd)

      map({ 't', 'n' }, '<C-h>', function() require('floaterm.api').switch_wins() end, { buffer = state.buf })

      map({ 'n', 't' }, '<C-j>', function() require('floaterm.api').cycle_term_bufs('next') end, { buffer = state.buf })

      map({ 'n', 't' }, '<C-k>', function() require('floaterm.api').cycle_term_bufs('prev') end, { buffer = state.buf })

      map('n', '<C-l>', function() require('floaterm.api').switch_wins() end, { buffer = state.buf })

      require('volt').mappings({
         bufs = { state.buf, state.sidebuf },
         after_close = function()
            state.volt_set = false
            state.terminals = nil
            state.buf = nil
            state.sidebuf = nil
            api.nvim_del_augroup_by_name('FloatermAu')
         end,
      })

      -- Remove volt's default close/cycle maps in favour of our own navigation
      for _, b in ipairs({ state.buf, state.sidebuf }) do
         for _, key in ipairs({ 'q', '<Esc>', '<C-t>' }) do
            pcall(vim.keymap.del, 'n', key, { buffer = b })
         end
      end

      if state.config.mappings.term then state.config.mappings.term(state.buf) end
   end

   if state.config.autoinsert then vim.cmd.startinsert() end
end

M.get_term_by_key = function(tocompare, name)
   name = name or 'buf'

   for i, v in ipairs(state.terminals or {}) do
      if tocompare == v[name] then return { i, v } end
   end
end

M.get_buf_on_cursor = function()
   local row = vim.api.nvim_win_get_cursor(0)[1]

   if not state.terminals[row] then
      vim.notify('place cursor on the terminal name', vim.log.levels.WARN)
      return
   end

   return row
end

return M
