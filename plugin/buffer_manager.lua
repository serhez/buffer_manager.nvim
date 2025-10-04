if vim.g.buffer_manager_loaded then return end
vim.g.buffer_manager_loaded = 1

-- Set up main keymap
local function setup_main_keymap()
  local config = require("buffer_manager").get_config()
  if config.main_keymap and config.main_keymap ~= "" then
    vim.keymap.set("n", config.main_keymap, 
      "<Cmd>lua require('buffer_manager.ui').handle_main_keymap()<CR>",
      { silent = true, desc = "Buffer Manager" })
  end
end

setup_main_keymap()

-- Auto-open menu on startup
vim.defer_fn(function()
  require("buffer_manager.ui").toggle_menu()
end, 100)

-- User command
vim.api.nvim_create_user_command("BufferManagerToggle", function()
  require("buffer_manager.ui").toggle_menu()
end, { desc = "Toggle buffer manager menu" })

-- Auto-refresh on buffer changes
local function is_menu_buffer(bufnr)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, 'buffer_manager_menu')
  return ok and val
end

local augroup = vim.api.nvim_create_augroup('BufferManagerRefresh', { clear = true })

vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout', 'BufUnload', 'BufEnter' }, {
  group = augroup,
  callback = function(args)
    if is_menu_buffer(args.buf) then return end
    if vim.bo[args.buf].buftype ~= '' and vim.bo[args.buf].buftype ~= 'terminal' then return end
    require('buffer_manager.ui').refresh_menu()
  end,
  desc = 'Auto-refresh buffer manager menu'
})
