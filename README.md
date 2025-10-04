<div align="center">

![bm_logo_simple](https://github.com/user-attachments/assets/5bb65a2a-358f-4c3f-a776-93df0242ccba)

### Minimalist Neovim Buffer Manager

[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)

</div>

## About

This plugin provides a minimalist buffer management system for Neovim with a unique transparent sidebar interface. The buffer manager displays as unobtrusive horizontal lines that expand to show buffer names and labels only when needed.

> **Note**: This plugin was originally created by [j-morano](https://github.com/j-morano/buffer_manager.nvim) and has been redesigned with a minimalist, transparent UI approach.

## Features

### Minimalist UI
- **Transparent Sidebar**: Middle-right positioned transparent floating window
- **Collapsed State**: Shows only horizontal dashes (─) for each buffer
- **Expanded State**: Reveals buffer labels and names when triggered
- **Auto-Collapse**: Returns to minimal dash display after buffer selection

### Smart Navigation
- **Quick Access**: Press trigger key (`;` by default) to expand labels
- **Smart Labels**: Automatically assigns intuitive single-key labels to buffers
- **Keyboard-Driven**: Select buffers with single keypresses

### Developer-Friendly
- **Complete Lua API**: All functionality exposed for custom configurations
- **Vim Commands**: Convenient `:BufferManagerToggle` command
- **Extensive Configuration**: Customize position, size, and appearance

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
-- - Press ";" to toggle the buffer manager (creates if not open)
-- - When closed, ";" opens it showing dashes
-- - When open (collapsed), ";" expands to show labels
-- - When expanded, ";" or ESC collapses back to dashes
-- - Press any label key to select that buffer
```

## Usage

### Opening the Buffer Manager

```lua
-- Toggle buffer manager
:BufferManagerToggle
-- or
:lua require("buffer_manager.ui").toggle_menu()
```

### Buffer Manager States

The buffer manager has two visual states:

#### Collapsed State (Default)
Shows only horizontal dashes for each buffer:
```
─────────────────────────
─────────────────────────
─────────────────────────
```

**Actions:**
- Press `;` to expand and show labels
- Press `q` or `ESC` to close the menu

#### Expanded State
Shows labels and buffer names:
```
a init.lua
s ui.lua
d README.md
```

**Actions:**
- Press any label key (`a`, `s`, `d`, etc.) to select that buffer
- Press `;`, `q`, or `ESC` to collapse back to dashes

### Smart Main Keymap Behavior

The main keymap (`;` by default) has context-aware behavior:

| State | Action | Result |
|-------|--------|---------|
| No menu open | Press `;` | Opens menu in collapsed state (dashes) |
| Menu closed, not focused | Press `;` | Opens menu in collapsed state |
| Menu open, collapsed | Press `;` | Expands to show labels and names |
| Menu open, expanded | Press `;` | Collapses back to dashes |
| Menu open, expanded | Press label key | Selects buffer and collapses to dashes |

### Navigation

#### Direct Buffer Selection
```lua
-- Navigate using the menu
-- 1. Open menu (;)
-- 2. Expand menu (;)
-- 3. Press label key (a, s, d, etc.)

-- Or programmatically:
require("buffer_manager.ui").nav_file(1) -- First buffer
require("buffer_manager.ui").nav_file(5) -- Fifth buffer
```

#### Sequential Navigation
```lua
-- Next/previous buffer in list
require("buffer_manager.ui").nav_next()
require("buffer_manager.ui").nav_prev()
```

### Buffer Management

The buffer list automatically updates when buffers are created or deleted. Buffers are ordered by last used time by default.

## Commands

Buffer Manager provides a simple Vim command:

```vim
:BufferManagerToggle  " Toggle the buffer manager menu
```

## Configuration

### Basic Configuration

```lua
require("buffer_manager").setup({
  -- Main keymap for toggling and expanding
  main_keymap = ";",
  
  -- Menu dimensions
  width = 30,  -- Width of the sidebar
  height = 15, -- Maximum height (adapts to buffer count)
  
  -- Position offsets
  offset_x = 2, -- Distance from right edge
  offset_y = 0, -- Vertical offset from center
  
  -- Visual customization
  dash_char = "─", -- Character used for collapsed state
})
```

### Advanced Configuration

```lua
require("buffer_manager").setup({
  -- Key bindings for buffer selection (smart labels)
  line_keys = {
    "a", "s", "d", "f", "r", "i", "o", "z", "x", "c", "n", "m",
  },
  
  -- Commands available in menu
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
  
  -- Highlight groups
  hl_label = "Search",     -- Highlight for label characters
  hl_filename = "Bold",    -- Highlight for filenames
  
  -- Navigation behavior
  loop_nav = true, -- Loop when using nav_next/nav_prev
})
```

### Complete Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `main_keymap` | string | `";"` | Primary key for menu toggle and expand |
| `width` | number | `30` | Width of the sidebar |
| `height` | number | `15` | Maximum height (adapts to buffer count) |
| `offset_x` | number | `2` | Distance from right edge of screen |
| `offset_y` | number | `0` | Vertical offset from center |
| `dash_char` | string | `"─"` | Character for collapsed state lines |
| `line_keys` | table | `{"a","s","d",...}` | Keys for buffer selection |
| `select_menu_item_commands` | table | See defaults | Menu commands and keys |
| `order_buffers` | string | `"lastused"` | Buffer ordering method |
| `loop_nav` | boolean | `true` | Loop navigation with nav_next/nav_prev |
| `hl_label` | string | `"Search"` | Highlight group for labels |
| `hl_filename` | string | `"Bold"` | Highlight group for filenames |

## Lua API

All functionality is exposed through the Lua API:

### Core Menu Functions
```lua
-- Toggle menu (create or close)
require("buffer_manager.ui").toggle_menu()

-- Smart keymap handler (used by main_keymap)
require("buffer_manager.ui").handle_main_keymap()

-- Manual state control
require("buffer_manager.ui").expand_menu()   -- Show labels
require("buffer_manager.ui").collapse_menu() -- Show dashes
require("buffer_manager.ui").close_menu()    -- Close completely
```

### Selection Functions
```lua
-- Select buffer by index
require("buffer_manager.ui").select_buffer(index)

-- Select buffer on current line with command
require("buffer_manager.ui").select_current_line(command)
```

### Navigation Functions
```lua
-- Direct buffer navigation
require("buffer_manager.ui").nav_file(index, command)
require("buffer_manager.ui").nav_next()
require("buffer_manager.ui").nav_prev()
```

### Utility Functions
```lua
-- Refresh menu display
require("buffer_manager.ui").refresh_menu()

-- Save buffer list to file
require("buffer_manager.ui").save_menu_to_file()
require("buffer_manager.ui").save_menu_to_file("filename")
```

## Example Keymaps

```lua
local opts = { noremap = true, silent = true }
local map = vim.keymap.set

-- Main buffer manager functionality
map("n", ";", require("buffer_manager.ui").handle_main_keymap, opts)

-- Alternative toggle
map("n", "<leader>b", ":BufferManagerToggle<CR>", opts)

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

### Custom Highlighting

```lua
-- Set custom colors
vim.api.nvim_set_hl(0, "BufferManagerLabel", { fg = "#ff6b6b", bold = true })
vim.api.nvim_set_hl(0, "BufferManagerFilename", { fg = "#69c0ff" })

-- Configure to use custom highlights
require("buffer_manager").setup({
  hl_label = "BufferManagerLabel",
  hl_filename = "BufferManagerFilename",
})
```

### Custom Position

```lua
-- Position at top-right instead of middle-right
require("buffer_manager").setup({
  offset_y = -10, -- Negative moves up from center
  offset_x = 1,   -- Closer to edge
})

-- Position at bottom-right
require("buffer_manager").setup({
  offset_y = 10,  -- Positive moves down from center
})
```

### Custom Dash Character

```lua
-- Use different characters for collapsed state
require("buffer_manager").setup({
  dash_char = "━", -- Thicker line
  -- or
  dash_char = "•", -- Bullets
  -- or
  dash_char = " ", -- Invisible (just spacing)
})
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

## License

This project maintains the same license as the original buffer_manager.nvim plugin.
