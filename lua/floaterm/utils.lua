local M = {}
local api = vim.api
local map = vim.keymap.set
local state = require('floaterm.state')
local volt = require('volt')
local volt_redraw = require('volt').redraw
local voltui = require('volt.ui')
local shell = vim.o.shell

local resize_timer
local resize_debounce = 100

M.resolve_dim = function(value, total, max)
   local n = value <= 1 and total * value or value
   local cap = max and (max <= 1 and total * max or max) or total
   return math.floor(math.min(n, cap))
end

M.convert_buf2term = function(cmd)
   if cmd then
      cmd = type(cmd) == 'function' and cmd() or cmd
      cmd = { shell, '-c', cmd }
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

M.set_term_keymaps = function()
   for i = 1, 9 do
      pcall(vim.keymap.del, 'n', tostring(i), { buffer = state.sidebuf })
   end
   for i, term in ipairs(state.terminals) do
      if i > 9 then break end
      M.add_keymap(i, term.buf)
   end
end

M.gen_term_bufs = function()
   for i, _ in ipairs(state.terminals) do
      state.terminals[i] = vim.tbl_extend('force', M.new_term(), state.terminals[i])
   end
   M.set_term_keymaps()
end

local num_icons = {
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

M.sidebar_lines = function()
   local lines = {}

   for i, v in ipairs(state.terminals) do
      local label = '  ' .. (v.name or 'term')
      local hl = state.buf == v.buf and 'FloatermActive' or 'Comment'
      local actions = { click = function() M.switch_buf(v.buf) end }
      local line = { { label, hl, actions }, { '_pad_' }, { num_icons[i] or tostring(i), hl } }
      table.insert(lines, voltui.hpad(line, 18))
   end

   local empty_lines_to_fill = state.h - #lines - 3
   for _ = 1, empty_lines_to_fill, 1 do
      table.insert(lines, {})
   end

   table.insert(lines, { { 'a - add', 'Comment' } })
   table.insert(lines, { { 'e - edit', 'Comment' } })
   table.insert(lines, { { 'd - delete', 'Comment' } })

   return lines
end

M.set_termwin_hl = function() vim.wo[state.win].winhl = 'Normal:FloatermNormal,FloatBorder:FloatermBorder' end

M.set_sidebar_hl = function()
   vim.wo[state.sidewin].winhl = 'Normal:FloatermSidebarNormal,FloatBorder:FloatermSidebarBorder'
end

M.set_highlights = function()
   local color = require('volt.color')
   local normal = api.nvim_get_hl(0, { name = 'Normal', link = false })
   local normal_bg = normal.bg and ('#%06x'):format(normal.bg) or '#000000'
   local contrast = state.config.contrast
   local darker = color.change_hex_lightness(normal_bg, -contrast)
   local lighter = color.change_hex_lightness(normal_bg, contrast)
   local diffadd = api.nvim_get_hl(0, { name = 'DiffAdd', link = false })

   api.nvim_set_hl(0, 'FloatermNormal', { bg = darker })
   api.nvim_set_hl(0, 'FloatermBorder', { bg = darker, fg = darker })
   api.nvim_set_hl(0, 'FloatermSidebarNormal', { bg = lighter })
   api.nvim_set_hl(0, 'FloatermSidebarBorder', { bg = lighter, fg = lighter })
   api.nvim_set_hl(0, 'FloatermActive', { fg = diffadd.fg })
end

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

M.render_sidebar = function(pos_row, pos_col)
   local sidebar_w = state.config.sidebar_w
   state.sidebar_win_opts = {
      row = pos_row,
      col = pos_col,
      width = sidebar_w,
      height = state.h,
      relative = 'editor',
      style = 'minimal',
      border = 'single',
      zindex = 100,
   }
   state.sidewin = api.nvim_open_win(state.sidebuf, true, state.sidebar_win_opts)
   M.set_sidebar_hl()

   volt.gen_data({
      { buf = state.sidebuf, ns = state.ns, layout = { { lines = M.sidebar_lines, name = 'bufs' } }, xpad = 1 },
   })
   api.nvim_set_option_value('modifiable', true, { buf = state.sidebuf })
   volt.run(state.sidebuf, { h = state.sidebar_win_opts.height, w = state.sidebar_win_opts.width })
   M.set_sidebar_keymaps()
   vim.bo[state.sidebuf].ft = 'FloatermSidebar'
end

M.render_terminal = function()
   local sidebar_w = state.config.sidebar_w
   state.term_win_opts = {
      row = -1,
      col = sidebar_w + 1,
      win = state.sidewin,
      width = state.w - sidebar_w,
      height = state.h,
      relative = 'win',
      style = 'minimal',
      border = { { ' ', 'FloatermBorder' } },
      zindex = 100,
   }
   state.win = api.nvim_open_win(state.buf, true, state.term_win_opts)
   M.set_termwin_hl()
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
            state.is_open = false
            state.terminals = nil
            state.buf = nil
            state.sidebuf = nil
         end,
      })

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

M.set_autocmds = function()
   local floaterm = require('floaterm')
   local grp = api.nvim_create_augroup('Floaterm', { clear = true })

   -- Keep our highlights in sync with the colorscheme (restyles an open floaterm live)
   api.nvim_create_autocmd('ColorScheme', { group = grp, callback = M.set_highlights })

   -- A managed terminal window closed (process exit, :q, ...) -> drop it from the list
   api.nvim_create_autocmd('WinClosed', {
      group = grp,
      callback = function(args)
         vim.schedule(function()
            if state.is_open and M.get_term_by_key(args.buf) then require('floaterm.api').delete_term(args.buf) end
         end)
      end,
   })

   -- Recompute geometry on editor resize by reopening (preserves terminal buffers).
   -- The reopen is deferred a tick so the close's scheduled WinClosed handler runs
   -- (and skips delete_term) before is_open is true again.
   api.nvim_create_autocmd('VimResized', {
      group = grp,
      callback = function()
         if not state.is_open then return end
         resize_timer = resize_timer or assert(vim.uv.new_timer())
         resize_timer:stop()
         resize_timer:start(
            resize_debounce,
            0,
            vim.schedule_wrap(function()
               if not state.is_open then return end
               floaterm.close()
               vim.schedule(floaterm.open)
            end)
         )
      end,
   })
end

return M
