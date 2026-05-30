local M = {}
local state = require "floaterm.state"
local utils = require "floaterm.utils"
local voltui = require "volt.ui"

local num_icons = {
  -- '󰎡',
  "󰎤",
  "󰎧",
  "󰎪",
  "󰎭",
  "󰎱",
  "󰎳",
  "󰎶",
  "󰎹",
  "󰎼",
}

M.items = function()
  local lines = {}

  for i, v in ipairs(state.terminals) do
    local icon = "  "
    local label = icon .. (v.name or "term")
    local hl = state.buf == v.buf and "ExGreen" or "Comment"
    local actions = {
      click = function()
        utils.switch_buf(v.buf)
      end,
    }
    local line = { { label, hl, actions }, { "_pad_" }, { num_icons[i] or tostring(i), hl } }
    table.insert(lines, voltui.hpad(line, 18))
  end

  -- separator + 3 help keymap lines
  local empty_lines_to_fill = state.h - #lines - 3

  for _ = 1, empty_lines_to_fill, 1 do
    table.insert(lines, { })
  end

  table.insert(lines, { { "a - add", "comment" } })
  table.insert(lines, { { "e - edit", "comment" } })
  table.insert(lines, { { "d - delete", "comment" } })

  return lines
end

return M
