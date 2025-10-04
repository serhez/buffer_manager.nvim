if vim.g.buffer_manager_loaded ~= nil then
  return
end
vim.g.buffer_manager_loaded = 1

-- Set up the main keymap globally
local function setup_main_keymap()
  local config = require("buffer_manager").get_config()
  if config.main_keymap and config.main_keymap ~= "" then
    vim.api.nvim_set_keymap(
      "n",
      config.main_keymap,
      "<Cmd>lua require('buffer_manager.ui').handle_main_keymap()<CR>",
      { silent = true, desc = "Buffer Manager" }
    )
  end
end

-- Set up the keymap immediately (removed defer to reduce perceived lag)
setup_main_keymap()

-- Auto-open menu on startup
vim.defer_fn(function()
  require("buffer_manager.ui").toggle_menu()
end, 100)

-- Create user command for menu
vim.api.nvim_create_user_command("BufferManagerToggle", function()
  require("buffer_manager.ui").toggle_menu()
end, {
  desc = "Toggle the buffer manager menu"
})

-- Autocmds to refresh menu when buffer list changes
local augroup = vim.api.nvim_create_augroup('BufferManagerRefresh', { clear = true })
vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout', 'BufUnload' }, {
  group = augroup,
  callback = function(args)
    local bufnr = args.buf
    -- Ignore our own menu buffers
    local ok, is_menu = pcall(vim.api.nvim_buf_get_var, bufnr, 'buffer_manager_menu')
    if ok and is_menu then return end
    -- Ignore unlisted or special buffers
    if vim.bo[bufnr].buftype ~= '' and vim.bo[bufnr].buftype ~= 'terminal' then return end
    -- Defer slightly to allow Neovim internal state to settle
    local ui = require('buffer_manager.ui')
    ui.refresh_menu()
  end,
  desc = 'Auto-refresh buffer_manager menu'
})
-- Track real buffer entries
local track_grp = vim.api.nvim_create_augroup('BufferManagerTrack', { clear = true })
vim.api.nvim_create_autocmd('BufEnter', {
  group = track_grp,
  callback = function(args)
    local bufnr = args.buf
    local ok, is_menu = pcall(vim.api.nvim_buf_get_var, bufnr, 'buffer_manager_menu')
    if ok and is_menu then return end
    if vim.bo[bufnr].buftype ~= '' and vim.bo[bufnr].buftype ~= 'terminal' then return end
    -- On entering a real buffer, refresh menu
    local ui = require('buffer_manager.ui')
    ui.refresh_menu()
  end,
  desc = 'Refresh buffer_manager menu on real buffer enter'
})
