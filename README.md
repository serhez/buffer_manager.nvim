<div align="center">

![bm_logo_simple](https://github.com/user-attachments/assets/5bb65a2a-358f-4c3f-a776-93df0242ccba)

### Minimalist Neovim Buffer Manager

[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)

</div>

## About

A minimalist buffer management system for Neovim with a transparent floating sidebar. The buffer manager displays as unobtrusive dashes that expand to show buffer names and smart labels only when needed.

> **Note**: This plugin was originally created by [j-morano](https://github.com/j-morano/buffer_manager.nvim) and has been redesigned with a minimalist, transparent UI approach.

## Features

### Minimalist UI
- **Transparent Sidebar**: Right-aligned transparent floating window
- **Collapsed State**: Shows only horizontal dashes (─) for each buffer
- **Expanded State**: Reveals buffer names and smart labels when triggered
- **Auto-Collapse**: Returns to minimal dash display after buffer selection
- **No Dependencies**: Works without plenary.nvim or any external dependencies

### Smart Navigation
- **Quick Access**: Press `;` to toggle/expand
- **Last Accessed Buffer**: Press `;` twice to switch to last accessed buffer (marked with `;` label)
- **Smart Labels**: Automatically assigns intuitive single-key labels based on filename
- **Keyboard-Driven**: Select buffers with single keypresses

### Extensible Actions
- **Built-in Actions**: Open (`<CR>`) and Delete (`d`) buffers
- **Custom Actions**: Define your own buffer actions (git stage, copy path, etc.)
- **Action Modes**: Press action key, then select buffer to apply action

### Visual Indicators
- **Current Buffer**: Bold highlighting
- **Active Buffers**: Normal highlighting (visible in other windows)
- **Inactive Buffers**: Comment highlighting (not visible)

## Installation

**Neovim 0.5.0+ required**

Install using your favorite plugin manager:

### lazy.nvim
```lua
{
  "your-username/buffer_manager.nvim",
  opts = {}
}
```

### packer.nvim
```lua
use({
  "your-username/buffer_manager.nvim",
  config = function()
    require("buffer_manager").setup({})
  end,
})
```

### vim-plug
```vim
Plug 'your-username/buffer_manager.nvim'
```

## Quick Start

The plugin works out of the box with sensible defaults:

```lua
-- Basic setup (optional - plugin works with defaults)
require("buffer_manager").setup({})

-- The main keymap ";" is automatically configured:
-- - Press ";" once: Opens menu (collapsed, shows dashes)
-- - Press ";" again: Expands menu (shows labels and buffer names)
-- - Press ";" third time: Switches to last accessed buffer
-- - Press any label key: Opens that buffer
-- - Press ESC: Collapses back to dashes
```

## Usage

### Buffer Manager States

The buffer manager has two visual states:

#### Collapsed State (Default)
Shows only horizontal dashes for each buffer:
```
──
 ─
──
```

**Visual Indicators:**
- `──` (double dash) = Active buffer (visible in some window)
- ` ─` (space + dash) = Inactive buffer (not visible)

**Actions:**
- Press `;` to expand and show labels
- Press `ESC` to close the menu

#### Expanded State
Shows buffer names with labels (right-aligned):
```
  init.lua a  
    ui.lua ;  ← Last accessed buffer
README.md s  
  test.lua d  
```

**Visual Indicators:**
- **Bold** = Current buffer (in focused window)
- Normal = Active buffer (in other windows)
- *Dimmed* = Inactive buffer (not visible)
- `;` label = Last accessed buffer (press `;` to switch to it)

**Actions:**
- Press any label key to open that buffer
- Press `;` to switch to last accessed buffer (marked with `;`)
- Press `<CR>` to enter open mode, then select buffer
- Press `d` to enter delete mode, then select buffer
- Press `ESC` to collapse back to dashes

### Action System

The buffer manager supports extensible actions with **visual feedback** through label color changes:

#### Built-in Actions

**Open Mode** (`<CR>`)
```
1. Press ; to expand menu
2. Press <CR> to enter open mode (labels stay yellow/default)
3. Press a label to open that buffer
```

**Delete Mode** (`d`)
```
1. Press ; to expand menu
2. Press d to enter delete mode (labels turn RED)
3. Press a label to delete that buffer
```

**Visual Feedback:**
- Normal mode: Labels use default highlight (Search - typically yellow/gold)
- Delete mode: Labels turn RED (ErrorMsg highlight) to indicate danger
- Custom modes: Labels use the highlight you specify

#### Custom Actions

Define custom actions with custom label colors:

```lua
require("buffer_manager").setup({
  actions = {
    -- Stage buffer in git (green labels)
    git_stage = {
      key = "g",
      hl = "DiffAdd",  -- Green labels for staging
      action = function(buf_id, buf_name)
        vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
        vim.notify("Staged: " .. buf_name)
      end,
    },
    -- Copy file path to clipboard (bright labels)
    copy_path = {
      key = "y",
      hl = "IncSearch",  -- Orange/bright labels
      action = function(buf_id, buf_name)
        vim.fn.setreg('+', buf_name)
        vim.notify("Copied: " .. buf_name)
      end,
    },
    -- Open in split (default labels)
    split_open = {
      key = "s",
      -- hl not specified - uses default
      action = function(buf_id, buf_name)
        vim.cmd("split")
        vim.cmd("buffer " .. buf_id)
      end,
    },
  }
})
```

**Action Definition Fields:**
- `key` (required): The key to activate this action mode
- `action` (required): The function to execute (receives buf_id and buf_name)
- `hl` (optional): Highlight group for labels in this mode (defaults to "Search" if not specified)

### Last Accessed Buffer

The last accessed buffer (not currently visible) is automatically labeled with `;`:

```lua
-- Quick workflow:
-- 1. Press ; to expand menu
-- 2. See which buffer has the ; label
-- 3. Press ; again to switch to it
-- Or press any other label to switch to that buffer instead
```

## Commands

```vim
:BufferManagerToggle  " Toggle the buffer manager menu
```

## Configuration

### Minimal Configuration

```lua
require("buffer_manager").setup({
  main_keymap = ";",        -- Main toggle/expand key
  offset_y = 0,             -- Vertical offset from center
  dash_char = "─",          -- Character for collapsed state
  label_padding = 1,        -- Padding around labels
  
  -- Built-in action highlights
  hl_open = "Search",       -- Default yellow/gold labels
  hl_delete = "ErrorMsg",   -- Red labels for delete mode
})
```

### Complete Configuration with Actions

```lua
require("buffer_manager").setup({
  -- Visual settings
  main_keymap = ";",
  offset_y = 0,
  dash_char = "─",
  label_padding = 1,
  
  -- Highlight groups
  hl_filename = "Bold",     -- Filename highlighting
  hl_open = "Search",       -- Open mode label highlighting
  hl_delete = "ErrorMsg",   -- Delete mode label highlighting (red)
  
  -- Smart label keys (automatically assigned)
  line_keys = {
    "a", "s", "d", "f", "r", "i", "o", "z", "x", "c", "n", "m"
  },
  
  -- Custom actions
  actions = {
    -- Add your custom actions here
    git_stage = {
      key = "g",
      action = function(buf_id, buf_name)
        vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
      end,
    },
  },
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `main_keymap` | string | `";"` | Primary key for menu toggle and expand |
| `offset_y` | number | `0` | Vertical offset from center |
| `dash_char` | string | `"─"` | Character for collapsed state lines |
| `label_padding` | number | `1` | Padding on left/right of labels |
| `line_keys` | table | `{"a","s","d",...}` | Keys for smart label assignment |
| `hl_filename` | string | `"Bold"` | Highlight group for filenames |
| `hl_open` | string | `"Search"` | Highlight group for open mode labels |
| `hl_delete` | string | `"ErrorMsg"` | Highlight group for delete mode labels |
| `actions` | table | Built-in actions | Action definitions (see Actions section) |
| `default_action` | string | `"open"` | Default action mode when menu expands |

## Lua API

### Core Functions

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

### Action Functions

```lua
-- Select buffer by index (executes current action)
require("buffer_manager.ui").select_buffer(index)

-- Enter action mode
require("buffer_manager.ui").set_action_mode("delete")
require("buffer_manager.ui").set_action_mode("git_stage") -- custom action
```

### Utility Functions

```lua
-- Refresh menu display
require("buffer_manager.ui").refresh_menu()
```

## Example Keymaps

```lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Main buffer manager functionality (automatically configured)
-- map("n", ";", require("buffer_manager.ui").handle_main_keymap, opts)

-- Alternative toggle
map("n", "<leader>b", ":BufferManagerToggle<CR>", opts)
```

## Advanced Usage

### Custom Highlighting

```lua
-- Simple: customize built-in action highlights
require("buffer_manager").setup({
  hl_open = "IncSearch",      -- Bright orange/yellow for open mode
  hl_delete = "DiagnosticError", -- Bright red for delete mode
  hl_filename = "Directory",   -- Custom color for filenames
})

-- Advanced: define custom highlights
vim.api.nvim_set_hl(0, "BMOpen", { fg = "#69c0ff", bold = true })
vim.api.nvim_set_hl(0, "BMDelete", { fg = "#ff6b6b", bold = true })

require("buffer_manager").setup({
  hl_open = "BMOpen",
  hl_delete = "BMDelete",
})

-- Or override via actions (for full control)
require("buffer_manager").setup({
  actions = {
    open = {
      key = "<CR>",
      hl = "String",  -- Green labels for open
      action = function(buf_id, buf_name)
        vim.cmd("buffer " .. buf_id)
      end,
    },
  },
})
```

### Custom Position

```lua
-- Position higher on screen
require("buffer_manager").setup({
  offset_y = -10,  -- Negative = up from center
})

-- Position lower on screen
require("buffer_manager").setup({
  offset_y = 10,   -- Positive = down from center
})
```

### Custom Dash Character

```lua
require("buffer_manager").setup({
  dash_char = "━",  -- Thicker line
  -- or
  dash_char = "•",  -- Bullets
  -- or
  dash_char = "│",  -- Vertical bar
})
```

## Action API Examples

### Git Integration

```lua
actions = {
  git_stage = {
    key = "g",
    action = function(buf_id, buf_name)
      vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
    end,
  },
  git_unstage = {
    key = "u",
    action = function(buf_id, buf_name)
      vim.cmd("!git reset " .. vim.fn.shellescape(buf_name))
    end,
  },
}
```

### File Operations

```lua
actions = {
  copy_path = {
    key = "y",
    action = function(buf_id, buf_name)
      vim.fn.setreg('+', buf_name)
      print("Copied: " .. buf_name)
    end,
  },
  copy_filename = {
    key = "Y",
    action = function(buf_id, buf_name)
      local name = vim.fn.fnamemodify(buf_name, ':t')
      vim.fn.setreg('+', name)
      print("Copied: " .. name)
    end,
  },
}
```

### Terminal Integration

```lua
actions = {
  run_file = {
    key = "r",
    action = function(buf_id, buf_name)
      vim.cmd("terminal " .. vim.fn.shellescape(buf_name))
    end,
  },
}
```

## Contributing

Contributions are welcome! Please open issues for bugs or feature requests, and pull requests for improvements.

## Acknowledgments

- **Original Plugin**: Created by [j-morano](https://github.com/j-morano/buffer_manager.nvim)
- **Inspiration**: [Harpoon](https://github.com/ThePrimeagen/harpoon) by ThePrimeagen

## License

This project maintains the same license as the original buffer_manager.nvim plugin.
