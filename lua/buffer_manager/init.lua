local utils = require("buffer_manager.utils")

local M = {}

BufferManagerConfig = BufferManagerConfig or {}
M.marks = {}

-- Built-in actions
M.actions = {
  open = {
    key = "<C-o>",
    hl = "Search", -- Will be overridden by hl_open config
    action = function(_, buf_name)
      local bufnr = vim.fn.bufnr(buf_name)
      if bufnr ~= -1 then
        vim.cmd("buffer " .. bufnr)
      else
        vim.cmd("edit " .. buf_name)
      end
      require("buffer_manager.ui").collapse_menu()
    end,
  },
  delete = {
    key = "<C-d>",
    hl = "ErrorMsg", -- Will be overridden by hl_delete config
    action = function(buf_id, _)
      vim.api.nvim_buf_delete(buf_id, { force = false })
      require("buffer_manager.ui").refresh_menu()
    end,
  },
}

-- Keys to use for labels
M.line_keys = {
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z",
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
}

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
    hl_filename = "Bold",
    hl_open = "Search", -- Highlight for open action labels
    hl_delete = "ErrorMsg", -- Highlight for delete action labels (red)
    main_keymap = ";",
    offset_y = 0,
    dash_char = "─",
    label_padding = 1,
    default_action = "open",
  }

  BufferManagerConfig = utils.merge_tables(default_config, config)

  -- Update built-in actions with configured highlights
  M.actions.open.hl = BufferManagerConfig.hl_open
  M.actions.delete.hl = BufferManagerConfig.hl_delete

  -- Set actions in config
  BufferManagerConfig.actions = M.actions

  -- Merge user actions with built-in actions
  if config.actions then
    BufferManagerConfig.actions = utils.merge_tables(M.actions, config.actions)
  end

  -- Filter out reserved keys (including action keys)
  local reserved = { "<Esc>", BufferManagerConfig.main_keymap }
  for _, action_config in pairs(BufferManagerConfig.actions) do
    if action_config.key then
      table.insert(reserved, action_config.key)
    end
  end
  M.line_keys = vim.tbl_filter(function(key)
    return not vim.tbl_contains(reserved, key)
  end, M.line_keys)
end

function M.get_config()
  return BufferManagerConfig or {}
end

M.setup()
M.initialize_marks()

return M
