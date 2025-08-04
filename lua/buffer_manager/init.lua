local Dev = require("buffer_manager.dev")
local log = Dev.log
local buffer_is_valid = require("buffer_manager.utils").buffer_is_valid
local merge_tables = require("buffer_manager.utils").merge_tables

local M = {}

BufferManagerConfig = BufferManagerConfig or {}

M.marks = {}

-- All keys in the keyboard (but for navigation keys)
M.extra_keys = {
  "0",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "a",
  "c",
  "d",
  "f",
  "i",
  "m",
  "n",
  "o",
  "r",
  "s",
  "t",
  "u",
  "x",
  "z",
}

function M.initialize_marks()
  local buffers = vim.api.nvim_list_bufs()

  for idx = 1, #buffers do
    local buf_id = buffers[idx]
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    local filename = buf_name
    -- if buffer is listed, then add to contents and marks
    if buffer_is_valid(buf_id, buf_name) then
      table.insert(M.marks, {
        filename = filename,
        buf_id = buf_id,
      })
    end
  end
end

function M.setup(config)
  log.trace("setup(): Setting up...")

  if not config then
    config = {}
  end

  local default_config = {
    line_keys = {
      "a",
      "s",
      "d",
      "f",
      "r",
      "i",
      "o",
      "z",
      "x",
      "c",
      "n",
      "m",
    },
    select_menu_item_commands = {
      edit = {
        key = "<CR>",
        command = "edit",
      },
    },
    focus_alternate_buffer = false,
    width = 65,
    height = 10,
    short_file_names = false,
    show_depth = true,
    short_term_names = false,
    loop_nav = true,
    highlight = "",
    hl_filename = "Bold",
    hl_path = "Comment",
    win_extra_options = {},
    borderchars = { "", "", "", "", "", "", "", "" },
    dir_separator_icon = "/",
    path_surrounding_icon = { "[", "]" },
    format_function = nil,
    order_buffers = "lastused",
    show_indicators = nil,
    main_keymap = ";",
    -- Persistent menu configuration
    persistent_menu = {
      enabled = true,
      width = 30,
      height = 15,
      position = "top-right", -- top-left, top-right, bottom-left, bottom-right
      offset_x = 0,
      offset_y = 1,
    },
  }

  local complete_config = merge_tables(default_config, config)

  -- Merge keys tables, keeping the order (first the line_keys, then the extra_keys)
  -- but avoid duplicates
  local merged_keys = {}
  local original_keys = complete_config.line_keys or {}
  local used_keys = {}

  -- First add all original line_keys
  for i = 1, #original_keys do
    local key = original_keys[i]
    if not used_keys[key] then
      table.insert(merged_keys, key)
      used_keys[key] = true
    end
  end

  -- Then add extra_keys that aren't already used
  for i = 1, #M.extra_keys do
    local key = M.extra_keys[i]
    if not used_keys[key] then
      table.insert(merged_keys, key)
      used_keys[key] = true
    end
  end

  complete_config.line_keys = merged_keys

  -- Remove important keys from line_keys
  complete_config.line_keys = vim.tbl_filter(function(key)
    return key ~= "q"
      and key ~= "w"
      and key ~= "e"
      and key ~= "b"
      and key ~= "g"
      and key ~= "v"
      and key ~= "y"
      and key ~= "p"
      and key ~= "h"
      and key ~= "j"
      and key ~= "k"
      and key ~= "l"
      and key ~= "<CR>"
      and key ~= "<Esc>"
      and key ~= complete_config.main_keymap -- Filter out main keymap
  end, complete_config.line_keys)
  for _, command in pairs(complete_config.select_menu_item_commands) do
    if command.key then
      complete_config.line_keys = vim.tbl_filter(function(key)
        return key ~= command.key
      end, complete_config.line_keys)
    end
  end

  BufferManagerConfig = complete_config
  log.debug("setup(): Config", BufferManagerConfig)
end

function M.get_config()
  log.trace("get_config()")
  return BufferManagerConfig or {}
end

-- Sets a default config with no values
M.setup()

M.initialize_marks()

return M
