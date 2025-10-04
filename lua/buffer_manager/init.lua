local utils = require("buffer_manager.utils")

local M = {}

BufferManagerConfig = BufferManagerConfig or {}
M.marks = {}

function M.initialize_marks()
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    if utils.buffer_is_valid(buf_id, buf_name) then
      table.insert(M.marks, { filename = buf_name, buf_id = buf_id })
    end
  end
end

function M.setup(config)
  config = config or {}

  local default_config = {
    line_keys = { "a", "s", "d", "f", "r", "i", "o", "z", "x", "c", "n", "m" },
    hl_label = "Search",
    hl_filename = "Bold",
    main_keymap = ";",
    offset_y = 0,
    dash_char = "─",
    label_padding = 1,
  }

  BufferManagerConfig = utils.merge_tables(default_config, config)

  -- Merge line_keys with extra keys, avoiding duplicates
  local extra_keys = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "b", "e", "g", "h", "l", "m", "n", "p", "t", "u", "v", "w", "y" }
  local used = {}
  local merged = {}

  for _, key in ipairs(BufferManagerConfig.line_keys) do
    if not used[key] then
      table.insert(merged, key)
      used[key] = true
    end
  end

  for _, key in ipairs(extra_keys) do
    if not used[key] then
      table.insert(merged, key)
      used[key] = true
    end
  end

  -- Filter out reserved keys
  local reserved = { "q", "j", "k", "<CR>", "<Esc>", BufferManagerConfig.main_keymap }
  BufferManagerConfig.line_keys = vim.tbl_filter(function(key)
    return not vim.tbl_contains(reserved, key)
  end, merged)
end

function M.get_config()
  return BufferManagerConfig or {}
end

M.setup()
M.initialize_marks()

return M
