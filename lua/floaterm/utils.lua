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

M.set_termwin_hl = function() vim.wo[state.win].winhl = 'Normal:FloatermNormal,FloatBorder:FloatermBorder' end

M.set_sidebar_hl = function() vim.wo[state.sidewin].winhl = 'Normal:NormalFloat,FloatBorder:FloatBorder' end

-- Define our highlight groups from the current colorscheme. Recomputed on demand
-- (open + ColorScheme) so they track theme changes. Terminal bg/border mirror
-- volt's logic: the Normal background darkened a touch.
M.set_highlights = function()
   local color = require('volt.color')
   local normal = api.nvim_get_hl(0, { name = 'Normal', link = false })
   local normal_bg = normal.bg and ('#%06x'):format(normal.bg) or '#000000'
   local darker = color.change_hex_lightness(normal_bg, -3)
   local diffadd = api.nvim_get_hl(0, { name = 'DiffAdd', link = false })

   api.nvim_set_hl(0, 'FloatermNormal', { bg = darker })
   api.nvim_set_hl(0, 'FloatermBorder', { bg = darker, fg = darker })
   api.nvim_set_hl(0, 'FloatermActive', { fg = diffadd.fg })
end

-- Buffer-local keymaps for the sidebar window
M.set_sidebar_keymaps = function()
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
