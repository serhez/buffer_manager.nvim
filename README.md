<div align="center">

![bm_logo_simple](https://github.com/user-attachments/assets/5bb65a2a-358f-4c3f-a776-93df0242ccba)

### Advanced Neovim Buffer Manager with Dual Menu System

[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)

</div>

## About

This plugin provides an advanced buffer management system for Neovim with **two distinct menu types**: a **Quick Menu** for temporary buffer switching and a **Persistent Menu** for always-available buffer access. The plugin offers Alt-Tab-style navigation, smart focus management, and extensive customization options.

> **Note**: This plugin was originally created by [j-morano](https://github.com/j-morano/buffer_manager.nvim) and has been heavily modified and enhanced with dual menu system, persistent popups, alt-tab navigation, smart keymap handling, and comprehensive API exposure.

## Features

### Dual Menu System
- **Quick Menu**: Centered popup with full file paths (traditional behavior)
- **Persistent Menu**: Positioned popup with filenames only (stays open)

### Smart Navigation
- **Alt-Tab Behavior**: Toggle between two most recent buffers with double keymap press
- **Focus-Aware Logic**: Different behavior based on menu focus state
- **Automatic Window Detection**: Always opens files in main window, never in popups

### Advanced Key Handling
- **Context-Sensitive Keys**: Same keys work differently based on menu state and focus
- **Configurable Main Keymap**: Customize the primary navigation key (default: `;`)
- **Per-Menu Keybindings**: Full Enter key support and label-based selection in both menus

### Developer-Friendly
- **Complete Lua API**: All functionality exposed for custom configurations
- **Vim Commands**: Convenient `:BufferManager*` commands for quick access
- **Extensive Configuration**: Fine-tune every aspect of both menu systems

## Installation

**Neovim 0.5.0+ required**

Install using your favorite plugin manager:

### lazy.nvim
```lua
{
  "your-username/buffer_manager.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {}
}
```

### packer.nvim
```lua
use({
  "your-username/buffer_manager.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("buffer_manager").setup({})
  end,
})
```

### vim-plug
```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'your-username/buffer_manager.nvim'
```

## Quick Start

The plugin works out of the box with sensible defaults:

```lua
-- Basic setup (optional - plugin works with defaults)
require("buffer_manager").setup({})

-- The main keymap ";" is automatically configured:
-- - Press ";" to open quick menu
-- - Press ";" again (or ";" + letter) for alt-tab behavior
-- - Use :BufferManagerTogglePersistent for persistent menu
```

## Usage

### Quick Menu (Traditional Buffer Switching)

```lua
-- Open quick menu
:BufferManagerToggleQuick
-- or
:lua require("buffer_manager.ui").toggle_quick_menu()
```

**Quick Menu Behavior:**
- **Centered popup** showing **full file paths**
- Press `Enter` or letter keys (`a`, `s`, `d`, etc.) to select buffer
- **Closes automatically** after selection
- Press `;` again to switch to last accessed buffer and close menu

### Persistent Menu (Always-Available Buffer Access)

```lua
-- Toggle persistent menu
:BufferManagerTogglePersistent
-- or
:lua require("buffer_manager.ui").toggle_persistent_menu()
```

**Persistent Menu Behavior:**
- **Positioned popup** (top-right by default) showing **filenames only**
- Press `Enter` or letter keys to select buffer
- **Stays open** after selection for quick successive switches
- When menu is open but not focused, `;` focuses the menu
- When menu is focused, `;` switches to last buffer and unfocuses menu

### Smart Main Keymap Behavior

The main keymap (`;` by default) has context-aware behavior:

| State | Action | Result |
|-------|--------|---------|
| No persistent menu open | Press `;` | Opens quick menu |
| In quick menu | Press `;` | Switch to last buffer & close menu |
| Persistent menu open, not focused | Press `;` | Focus persistent menu |
| Persistent menu focused | Press `;` | Switch to last buffer & unfocus menu |
| In any menu | Press letter | Open corresponding buffer |

### Alt-Tab Style Navigation

Press the main keymap twice quickly to toggle between your two most recent buffers:
- `;` `;` - Switch between current and previous buffer
- Works from both menus and main editing windows
- Maintains buffer history for seamless navigation

### Buffer Management

#### Navigation
```lua
-- Next/previous buffer in list
require("buffer_manager.ui").nav_next()
require("buffer_manager.ui").nav_prev()

-- Direct navigation to buffer by index
require("buffer_manager.ui").nav_file(1) -- First buffer
require("buffer_manager.ui").nav_file(5) -- Fifth buffer
```

#### Buffer Operations
- **Add buffer**: Write filename in menu (supports autocomplete with `<C-x><C-f>`)
- **Remove buffer**: Delete line in menu (doesn't remove terminal or modified buffers)
- **Reorder buffers**: Move lines up/down in menu

#### Save Buffer Lists
```lua
-- Interactive filename input
require("buffer_manager.ui").save_menu_to_file()

-- Direct filename
require("buffer_manager.ui").save_menu_to_file("my_session.txt")
```

## Commands

Buffer Manager provides convenient Vim commands:

```vim
:BufferManagerToggleQuick       " Toggle quick menu (centered popup)
:BufferManagerTogglePersistent  " Toggle persistent menu (positioned popup)
```

## Configuration

### Basic Configuration

```lua
require("buffer_manager").setup({
  -- Main keymap for opening menus and alt-tab behavior
  main_keymap = ";",

  -- Quick menu configuration (centered popup)
  width = 90, -- Width of quick menu
  height = 15, -- Height of quick menu
  short_file_names = false, -- Show full paths in quick menu

  -- Persistent menu configuration (positioned popup)
  persistent_menu = {
    enabled = true,
    width = 50, -- Width of persistent menu
    height = 15, -- Height of persistent menu
    position = "top-right", -- Position: "top-left", "top-right", "bottom-left", "bottom-right"
    offset_x = 2, -- Horizontal offset from edge
    offset_y = 2, -- Vertical offset from edge
  },
})
```

### Advanced Configuration

```lua
require("buffer_manager").setup({
  -- Key bindings for buffer selection
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

  -- Commands available in menus
  select_menu_item_commands = {
    edit = {
      key = "<CR>",
      command = "edit",
    },
    split = {
      key = "<C-s>",
      command = "split",
    },
    vsplit = {
      key = "<C-v>",
      command = "vsplit",
    },
  },

  -- Buffer ordering
  order_buffers = "lastused", -- "filename", "bufnr", "lastused", "fullpath"

  -- Visual customization
  highlight = "Normal:BufferManagerBorder",
  borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },

  -- Window options
  win_extra_options = {
    winhighlight = "Normal:BufferManagerNormal",
  },
})
```

### Complete Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `main_keymap` | string | `";"` | Primary key for menu navigation and alt-tab |
| `line_keys` | table | `{"a","s","d",...}` | Keys for buffer selection |
| `select_menu_item_commands` | table | `{edit={key="<CR>",command="edit"}}` | Menu commands |
| `focus_alternate_buffer` | boolean | `false` | Focus alternate buffer instead of current |
| `width` | number | `65` | Quick menu width |
| `height` | number | `10` | Quick menu height |
| `short_file_names` | boolean | `false` | Show shortened paths in quick menu |
| `show_depth` | boolean | `true` | Show directory depth |
| `short_term_names` | boolean | `false` | Shorten terminal buffer names |
| `loop_nav` | boolean | `true` | Loop navigation with nav_next/nav_prev |
| `highlight` | string | `""` | Window highlight override |
| `win_extra_options` | table | `{}` | Additional window options |
| `borderchars` | table | See defaults | Border characters |
| `format_function` | function | `nil` | Custom buffer name formatting |
| `order_buffers` | string | `"lastused"` | Buffer ordering method |
| `show_indicators` | string | `nil` | Show buffer indicators ("before"/"after") |
| `persistent_menu.enabled` | boolean | `true` | Enable persistent menu |
| `persistent_menu.width` | number | `50` | Persistent menu width |
| `persistent_menu.height` | number | `15` | Persistent menu height |
| `persistent_menu.position` | string | `"top-right"` | Menu position |
| `persistent_menu.offset_x` | number | `2` | Horizontal offset |
| `persistent_menu.offset_y` | number | `2` | Vertical offset |

## Lua API

All functionality is exposed through the Lua API for advanced users:

### Core Menu Functions
```lua
-- Toggle menus
require("buffer_manager.ui").toggle_quick_menu()
require("buffer_manager.ui").toggle_persistent_menu()

-- Smart keymap handler (used by main_keymap)
require("buffer_manager.ui").handle_main_keymap()
```

### Navigation Functions
```lua
-- Direct buffer navigation
require("buffer_manager.ui").nav_file(index, command)
require("buffer_manager.ui").nav_next()
require("buffer_manager.ui").nav_prev()

-- Alt-tab navigation
require("buffer_manager.ui").nav_to_last_buffer_from_quick()
require("buffer_manager.ui").nav_to_last_buffer_from_persistent()
```

### Selection Functions
```lua
-- Menu item selection
require("buffer_manager.ui").select_menu_item(command)
require("buffer_manager.ui").select_persistent_buffer(index)
require("buffer_manager.ui").select_persistent_menu_item(command)
```

### File Management
```lua
-- Save buffer lists
require("buffer_manager.ui").save_menu_to_file()
require("buffer_manager.ui").save_menu_to_file("filename")
```

## Example Keymaps

```lua
local opts = { noremap = true, silent = true }
local map = vim.keymap.set

-- Main buffer manager functionality
map("n", ";", require("buffer_manager.ui").handle_main_keymap, opts)

-- Menu toggles
map("n", "<leader>bq", ":BufferManagerToggleQuick<CR>", opts)
map("n", "<leader>bp", ":BufferManagerTogglePersistent<CR>", opts)

-- Navigation
map("n", "<C-n>", require("buffer_manager.ui").nav_next, opts)
map("n", "<C-p>", require("buffer_manager.ui").nav_prev, opts)

-- Direct buffer access (bypassing menu)
local bmui = require("buffer_manager.ui")
for i = 1, 9 do
  map("n", "<leader>" .. i, function()
    bmui.nav_file(i)
  end, opts)
end
```

## Advanced Usage

### Custom Menu Reordering

Set up visual mode keymaps to reorder buffers in menus:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "buffer_manager",
  callback = function()
    vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { buffer = true })
    vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { buffer = true })
  end,
})
```

### Custom Highlighting

```lua
-- Set custom colors for modified buffers
vim.api.nvim_set_hl(0, "BufferManagerModified", { fg = "#ff6b6b" })

-- Configure window highlights
require("buffer_manager").setup({
  highlight = "Normal:BufferManagerBorder",
  win_extra_options = {
    winhighlight = "Normal:BufferManagerNormal,FloatBorder:BufferManagerBorder",
  },
})
```

### Integration with Other Plugins

```lua
-- Example: Integration with telescope for buffer preview
map("n", "<leader>bf", function()
  require("buffer_manager.ui").toggle_quick_menu()
  vim.defer_fn(function()
    vim.cmd("Telescope live_grep")
  end, 100)
end, opts)
```

## Logging

- Logs are written to `buffer_manager.log` in Neovim's cache directory (`:echo stdpath("cache")`)
- Log levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal` (default: `warn`)
- Set log level with `vim.g.buffer_manager_log_level` (before `setup()`)
- Environment variable `BUFFER_MANAGER_LOG=debug nvim` overrides config setting

## Contributing

Contributions are welcome! Please open issues for bugs or feature requests, and pull requests for improvements.

## Acknowledgments

- **Original Plugin**: Created by [j-morano](https://github.com/j-morano/buffer_manager.nvim)
- **Inspiration**: [Harpoon](https://github.com/ThePrimeagen/harpoon) by ThePrimeagen
- **Buffer Management**: [bufdelete.nvim](https://github.com/famiu/bufdelete.nvim) for proper buffer deletion

## License

This project maintains the same license as the original buffer_manager.nvim plugin.
