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

-- Set up the keymap after a short delay to ensure config is loaded
vim.defer_fn(setup_main_keymap, 50)

-- Create user commands for both menu types
vim.api.nvim_create_user_command("BufferManagerTogglePersistent", function()
  require("buffer_manager.ui").toggle_persistent_menu()
end, {
  desc = "Toggle the persistent buffer manager menu"
})

vim.api.nvim_create_user_command("BufferManagerToggleQuick", function()
  require("buffer_manager.ui").toggle_quick_menu()
end, {
  desc = "Toggle the quick buffer manager menu"
})
