<div align="center">

![bm_logo_simple](https://github.com/user-attachments/assets/5bb65a2a-358f-4c3f-a776-93df0242ccba)

### Minimalist Neovim Buffer Manager

[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)

</div>

A minimalist buffer manager with a transparent floating sidebar. Shows unobtrusive dashes that expand to reveal buffer names and smart labels when needed.

> **Note**: Originally created by [j-morano](https://github.com/j-morano/buffer_manager.nvim), redesigned with a minimalist approach.

## Features

- **Transparent sidebar** with collapsed (dashes only) and expanded (labels + names) states
- **Smart label assignment** based on filenames for quick buffer switching
- **Last accessed buffer** quick switch (press `;` twice)
- **Extensible action system** with visual feedback (open, delete, custom actions)
- **Visual indicators** for current, active, and inactive buffers
- **Buffer limit enforcement** with LRU deletion (optional)
- **Auto-collapse** on selection and cursor movement
- **No dependencies**

## Installation

Neovim 0.5.0+ required. Works with any plugin manager:

```lua
-- lazy.nvim
{ "your-username/buffer_manager.nvim", opts = {} }

-- packer.nvim
use({ "your-username/buffer_manager.nvim", config = function() require("buffer_manager").setup() end })
```

## Quick Start

Works out of the box with defaults. Main keymap is `;`:

- `;` once → Open menu (collapsed, shows dashes)
- `;` twice → Expand menu (shows labels and names) / Switch to last accessed buffer
- Label key → Open that buffer
- `<C-o>` → Enter open mode, then select buffer
- `<C-d>` → Enter delete mode, then select buffer
- `ESC` → Collapse back to dashes

## Visual States

**Collapsed (default):** Shows dashes only
- `──` = Active buffer (visible)
- ` ─` = Inactive buffer (hidden)

**Expanded:** Shows buffer names + labels (right-aligned)
- **Bold** = Current buffer
- Normal = Active in other windows
- *Dimmed* = Inactive
- `;` label = Last accessed buffer

## Actions

Actions change label colors for visual feedback. Built-in actions:
- **Open** (`<C-o>`): Opens selected buffer (default yellow labels)
- **Delete** (`<C-d>`): Deletes selected buffer (red labels)

### Custom Actions

```lua
require("buffer_manager").setup({
  actions = {
    git_stage = {
      key = "g",
      hl = "DiffAdd",  -- Optional: custom label color
      action = function(buf_id, buf_name)
        vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
      end,
    },
  }
})
```

Action fields: `key` (required), `action` (required), `hl` (optional highlight group)

## Configuration

All options with defaults:

```lua
require("buffer_manager").setup({
  main_keymap = ";",            -- Main toggle/expand key
  offset_y = 0,                 -- Vertical offset from center
  dash_char = "─",              -- Character for collapsed dashes
  label_padding = 1,            -- Padding around labels
  max_open_buffers = -1,        -- Max buffers (-1 = unlimited)
  default_action = "open",      -- Action when pressing label directly

  -- Highlight groups
  hl_filename = "Bold",         -- Current buffer filename
  hl_inactive = "Comment",      -- Inactive buffer dashes
  hl_open = "Search",           -- Open action labels
  hl_delete = "ErrorMsg",       -- Delete action labels

  -- Custom actions
  actions = {},
})
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `main_keymap` | string | `";"` | Primary key for menu toggle and expand |
| `offset_y` | number | `0` | Vertical offset from center |
| `dash_char` | string | `"─"` | Character for collapsed state lines |
| `label_padding` | number | `1` | Padding on left/right of labels |
| `max_open_buffers` | number | `-1` | Maximum number of buffers to keep open (`-1` = unlimited) |
| `hl_filename` | string | `"Bold"` | Highlight group for filenames |
| `hl_inactive` | string | `"Comment"` | Highlight group for inactive buffer dashes |
| `hl_open` | string | `"Search"` | Highlight group for open mode labels |
| `hl_delete` | string | `"ErrorMsg"` | Highlight group for delete mode labels |
| `actions` | table | Built-in actions | Action definitions (see Actions section) |
| `default_action` | string | `"open"` | Default action mode when menu expands |

### Buffer Limit

Set `max_open_buffers` to automatically close least recently used buffers:
- Visible and current buffers are never closed
- Uses Neovim's native buffer access tracking
- Enforced at startup and when opening new buffers

```lua
max_open_buffers = 10  -- Keep max 10 buffers (-1 = unlimited)
```

## Lua API

```lua
-- Menu control
require("buffer_manager.ui").toggle_menu()
require("buffer_manager.ui").expand_menu()
require("buffer_manager.ui").collapse_menu()
require("buffer_manager.ui").close_menu()
require("buffer_manager.ui").refresh_menu()

-- Actions
require("buffer_manager.ui").set_action_mode("delete")
require("buffer_manager.ui").select_buffer(index)

-- Command
:BufferManagerToggle
```

## Examples

### Custom Highlighting

```lua
require("buffer_manager").setup({
  hl_open = "IncSearch",
  hl_delete = "DiagnosticError",
})
```

### Override Built-in Actions

```lua
require("buffer_manager").setup({
  actions = {
    open = {
      key = "<CR>",  -- Change from default <C-o>
      hl = "String",
      action = function(buf_id, buf_name)
        vim.cmd("buffer " .. buf_id)
        require("buffer_manager.ui").collapse_menu()
      end,
    },
  },
})
```

### Custom Action Examples

```lua
actions = {
  -- Git
  git_stage = { key = "g", action = function(_, buf_name)
    vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
  end },

  -- Copy path
  copy_path = { key = "y", action = function(_, buf_name)
    vim.fn.setreg('+', buf_name)
  end },

  -- Open in split
  split = { key = "s", action = function(buf_id)
    vim.cmd("split | buffer " .. buf_id)
  end },
}
```

## Contributing

Contributions are welcome! Please open issues for bugs or feature requests, and pull requests for improvements.

## Acknowledgments

- **Original Plugin**: Created by [j-morano](https://github.com/j-morano/buffer_manager.nvim)
- **Inspiration**: [Harpoon](https://github.com/ThePrimeagen/harpoon) by ThePrimeagen

## License

This project maintains the same license as the original buffer_manager.nvim plugin.
