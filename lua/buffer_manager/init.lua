local utils = require("buffer_manager.utils")

local M = {}

BufferManagerConfig = BufferManagerConfig or {}
M.marks = {}

function M.get_config()
  return BufferManagerConfig or {}
end

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

local function setup_main_keymap()
  local config = M.get_config()
  vim.notify(
    "Setting main keymap: " .. tostring(config.main_keymap),
    vim.log.levels.DEBUG
  )
  if config.main_keymap and config.main_keymap ~= "" then
    vim.keymap.set(
      "n",
      config.main_keymap,
      "<Cmd>lua require('buffer_manager.ui').handle_main_keymap()<CR>",
      { silent = true, desc = "Buffer Manager" }
    )
  end
end

local function setup_autocmds()
  -- User command
  vim.api.nvim_create_user_command("BufferManagerToggle", function()
    require("buffer_manager.ui").toggle_menu()
  end, { desc = "Toggle buffer manager menu" })

  -- Auto-refresh on buffer and window changes
  local function is_menu_buffer(bufnr)
    local ok, val =
      pcall(vim.api.nvim_buf_get_var, bufnr, "buffer_manager_menu")
    return ok and val
  end

  local augroup =
    vim.api.nvim_create_augroup("BufferManagerRefresh", { clear = true })

  -- Single autocmd for all refresh events
  vim.api.nvim_create_autocmd(
    { "BufAdd", "BufDelete", "BufWipeout", "BufEnter", "WinEnter" },
    {
      group = augroup,
      callback = function(args)
        if is_menu_buffer(args.buf) then
          return
        end
        if
          vim.bo[args.buf].buftype ~= ""
          and vim.bo[args.buf].buftype ~= "terminal"
        then
          return
        end
        require("buffer_manager.ui").refresh_menu()
      end,
      desc = "Auto-refresh buffer manager menu",
    }
  )

  -- Autocmd to update the current window
  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup,
    callback = function(args)
      if is_menu_buffer(args.buf) then
        return
      end
      local win_id = vim.api.nvim_get_current_win()
      if not win_id or win_id == nil then
        return
      end
      require("buffer_manager.ui").set_last_editor_win(win_id)
    end,
    desc = "Update current window in buffer manager menu",
  })

  -- Autocmd to collapse the menu when moving the cursor in the editor
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    callback = function(args)
      if is_menu_buffer(args.buf) then
        return
      end
      require("buffer_manager.ui").collapse_menu()
    end,
    desc = "Collapse buffer manager menu on cursor move",
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup,
    callback = function(args)
      if is_menu_buffer(args.buf) then
        return
      end
      local win_id = vim.api.nvim_get_current_win()
      if not win_id or win_id == nil then
        return
      end
      require("buffer_manager.ui").set_last_editor_win(win_id)
    end,
    desc = "Update current window in buffer manager menu",
  })

  -- Autocmd to refresh menu when terminal is resized
  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      require("buffer_manager.ui").refresh_menu()
    end,
    desc = "Refresh buffer manager menu on window resize",
  })

  -- Enforce buffer limit when a new buffer is added
  vim.api.nvim_create_autocmd("BufAdd", {
    group = augroup,
    callback = function(args)
      if is_menu_buffer(args.buf) then
        return
      end
      require("buffer_manager").enforce_buffer_limit()
    end,
    desc = "Enforce maximum buffer limit",
  })
end

function M.initialize_marks()
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    if utils.buffer_is_valid(buf_id, buf_name) then
      table.insert(M.marks, { filename = buf_name, buf_id = buf_id })
    end
  end
end

-- Get least recently used buffer (excluding current buffer and visible buffers)
function M.get_lru_buffer()
  local current_buf = vim.api.nvim_get_current_buf()
  local visible_bufs = {}

  -- Collect all visible buffers
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      visible_bufs[buf] = true
    end
  end

  local lru_buf = nil
  local lru_time = math.huge

  -- Find the least recently used buffer using Neovim's built-in lastused
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    if
      utils.buffer_is_valid(buf_id, buf_name)
      and buf_id ~= current_buf
      and not visible_bufs[buf_id]
    then
      local buf_info = vim.fn.getbufinfo(buf_id)[1]
      if buf_info then
        local lastused = buf_info.lastused or 0
        if lastused < lru_time then
          lru_time = lastused
          lru_buf = buf_id
        end
      end
    end
  end

  return lru_buf
end

-- Enforce buffer limit by deleting LRU buffer if needed
function M.enforce_buffer_limit()
  local config = M.get_config()
  if config.max_open_buffers <= 0 then
    return -- No limit
  end

  -- Count valid buffers
  local valid_buffers = 0
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    if utils.buffer_is_valid(buf_id, buf_name) then
      valid_buffers = valid_buffers + 1
    end
  end

  -- Delete LRU buffers until we're under the limit
  while valid_buffers > config.max_open_buffers do
    local lru_buf = M.get_lru_buffer()
    if not lru_buf then
      break -- No more buffers to delete
    end

    pcall(vim.api.nvim_buf_delete, lru_buf, { force = false })
    valid_buffers = valid_buffers - 1
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
    max_open_buffers = -1, -- Maximum number of open buffers (-1 = unlimited)
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

  setup_main_keymap()

  -- Enforce buffer limit
  vim.defer_fn(function()
    require("buffer_manager").enforce_buffer_limit()
  end, 50)

  -- Auto-open menu
  vim.defer_fn(function()
    require("buffer_manager.ui").toggle_menu()
  end, 100)

  setup_autocmds()

  M.initialize_marks()
end

return M
