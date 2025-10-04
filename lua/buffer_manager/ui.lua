local buffer_manager = require("buffer_manager")
local utils = require("buffer_manager.utils")
local log = require("buffer_manager.dev").log
local marks = require("buffer_manager").marks

local M = {}

-- State variables
Buffer_manager_win_id = nil
Buffer_manager_bufh = nil
local last_editor_win = nil
local config = buffer_manager.get_config()
local is_expanded = false
local selection_mode_keymaps = {}

-- Set up highlight group for transparent background
vim.api.nvim_set_hl(0, "BufferManagerNormal", { bg = "NONE", fg = "NONE" })

-- Check if buffer is visible in current tab
local function is_buffer_visible_in_tab(buf_id)
  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if
      vim.api.nvim_win_is_valid(win_id)
      and vim.api.nvim_win_get_buf(win_id) == buf_id
    then
      return true
    end
  end
  return false
end

-- Get the last accessed buffer not currently visible
local function get_last_accessed_buffer()
  local sorted_buffers = {}
  for _, mark in ipairs(marks) do
    if vim.api.nvim_buf_is_valid(mark.buf_id) then
      local buf_info = vim.fn.getbufinfo(mark.buf_id)[1]
      if buf_info then
        table.insert(
          sorted_buffers,
          { buf_id = mark.buf_id, lastused = buf_info.lastused }
        )
      end
    end
  end

  table.sort(sorted_buffers, function(a, b)
    return a.lastused > b.lastused
  end)

  for _, buf_info in ipairs(sorted_buffers) do
    if not is_buffer_visible_in_tab(buf_info.buf_id) then
      return buf_info.buf_id
    end
  end
  return nil
end

-- Get the index of a buffer in the marks list
local function get_buffer_index(buf_id)
  for i, mark in ipairs(marks) do
    if mark.buf_id == buf_id then
      return i
    end
  end
  return nil
end

-- Find main content window (non-floating)
local function find_main_window()
  local current_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(current_win).relative == "" then
    return current_win
  end
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win_id).relative == "" then
      return win_id
    end
  end
  return current_win
end

-- Update marks (buffer list)
local function update_marks()
  -- Remove invalid buffers
  for idx = #marks, 1, -1 do
    if not utils.buffer_is_valid(marks[idx].buf_id, marks[idx].filename) then
      table.remove(marks, idx)
    end
  end

  -- Add new buffers
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    if utils.buffer_is_valid(buf, bufname) then
      local found = false
      for _, mark in ipairs(marks) do
        if mark.buf_id == buf then
          found = true
          break
        end
      end
      if not found then
        table.insert(marks, { filename = bufname, buf_id = buf })
      end
    end
  end
end

-- Assign smart labels to buffers
local function assign_smart_labels(buffers, available_keys)
  local label_assignment = {}
  local used_labels = {}
  local last_accessed_buf = get_last_accessed_buffer()

  -- Assign ";" to last accessed buffer
  if last_accessed_buf then
    for i, mark in ipairs(buffers) do
      if mark.buf_id == last_accessed_buf then
        label_assignment[i] = ";"
        used_labels[";"] = true
        break
      end
    end
  end

  -- Try to match first alphanumeric character
  for i, mark in ipairs(buffers) do
    if label_assignment[i] or i > #available_keys then
      goto continue
    end

    local first_alnum = utils.get_file_name(mark.filename):match("[%w]")
    if first_alnum then
      local key = string.lower(first_alnum)
      if vim.tbl_contains(available_keys, key) and not used_labels[key] then
        label_assignment[i] = key
        used_labels[key] = true
      end
    end
    ::continue::
  end

  -- Fill remaining with available keys
  local key_idx = 1
  for i = 1, math.min(#buffers, #available_keys) do
    if not label_assignment[i] then
      while
        key_idx <= #available_keys and used_labels[available_keys[key_idx]]
      do
        key_idx = key_idx + 1
      end
      if key_idx <= #available_keys then
        label_assignment[i] = available_keys[key_idx]
        used_labels[available_keys[key_idx]] = true
        key_idx = key_idx + 1
      end
    end
  end

  return label_assignment
end

-- Create the transparent floating window
local function create_window(height, width)
  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2) + (config.offset_y or 0)
  local col = ui.width - width + 1

  local bufnr = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "none",
    focusable = false,
  })

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_win_set_option(win_id, "wrap", false)
  vim.api.nvim_win_set_option(win_id, "winblend", 0)
  vim.api.nvim_win_set_option(
    win_id,
    "winhighlight",
    "Normal:BufferManagerNormal"
  )

  return { bufnr = bufnr, win_id = win_id }
end

-- Update window size dynamically
local function update_window_size(width, height)
  if
    not Buffer_manager_win_id
    or not vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    return
  end

  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2) + (config.offset_y or 0)
  local col = ui.width - width + 1

  pcall(vim.api.nvim_win_set_config, Buffer_manager_win_id, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
  })
end

-- Check if buffer is active (visible in any window)
local function is_buffer_active(buf_id)
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if
      vim.api.nvim_win_is_valid(win_id)
      and vim.api.nvim_win_get_buf(win_id) == buf_id
    then
      return true
    end
  end
  return false
end

-- Check if buffer is the current buffer in the last editor window
local function is_current_buffer(buf_id)
  return last_editor_win
    and vim.api.nvim_win_is_valid(last_editor_win)
    and vim.api.nvim_win_get_buf(last_editor_win) == buf_id
end

-- Generate dash line for a buffer
local function generate_dash_line(buf_id)
  return is_buffer_active(buf_id) and (config.dash_char:rep(2))
    or (" " .. config.dash_char)
end

-- Clear all selection mode keymaps
local function clear_selection_keymaps()
  for _, key in ipairs(selection_mode_keymaps) do
    pcall(vim.keymap.del, "n", key)
  end
  selection_mode_keymaps = {}
end

-- Set global keybindings for selection mode (expanded state)
local function set_selection_keybindings(smart_labels)
  clear_selection_keymaps()

  for i, label in pairs(smart_labels) do
    -- Don't override the main keymap (";")
    if label and label ~= " " and label ~= config.main_keymap then
      vim.keymap.set("n", label, function()
        require("buffer_manager.ui").select_buffer(i)
      end, { silent = true, desc = "Buffer Manager: Select buffer " .. i })
      table.insert(selection_mode_keymaps, label)
    end
  end

  -- ESC to collapse
  vim.keymap.set("n", "<ESC>", function()
    require("buffer_manager.ui").collapse_menu()
  end, { silent = true, desc = "Buffer Manager: Collapse menu" })
  table.insert(selection_mode_keymaps, "<ESC>")
end

-- Display menu in collapsed state (dashes only)
local function render_collapsed()
  if
    not Buffer_manager_bufh
    or not vim.api.nvim_buf_is_valid(Buffer_manager_bufh)
  then
    return
  end

  update_marks()
  local contents = {}
  local padding = config.label_padding or 1
  local padding_str = string.rep(" ", padding)

  for i = 1, #marks do
    contents[i] = padding_str
      .. generate_dash_line(marks[i].buf_id)
      .. padding_str
  end

  vim.api.nvim_buf_set_option(Buffer_manager_bufh, "modifiable", true)
  vim.api.nvim_buf_set_lines(Buffer_manager_bufh, 0, -1, false, contents)
  vim.api.nvim_buf_set_option(Buffer_manager_bufh, "modifiable", false)

  -- Update window size: width = 2 (for dash) + 2 * padding, height = number of buffers
  local dash_width =
    vim.fn.strwidth(generate_dash_line(marks[1] and marks[1].buf_id or 0))
  update_window_size(dash_width + 2 * padding, #marks)

  -- Add highlighting for inactive buffers
  local ns_id = vim.api.nvim_create_namespace("BufferManagerDash")
  vim.api.nvim_buf_clear_namespace(Buffer_manager_bufh, ns_id, 0, -1)

  for i, mark in ipairs(marks) do
    if not is_buffer_active(mark.buf_id) then
      -- Highlight entire line for inactive buffers with "Comment" highlight group
      vim.api.nvim_buf_add_highlight(
        Buffer_manager_bufh,
        ns_id,
        config.hl_inactive or "Comment",
        i - 1,
        0,
        -1
      )
    end
  end

  -- Clear selection mode keymaps
  clear_selection_keymaps()
end

-- Display menu in expanded state (labels + names)
local function render_expanded()
  if
    not Buffer_manager_bufh
    or not vim.api.nvim_buf_is_valid(Buffer_manager_bufh)
  then
    return
  end

  update_marks()
  local smart_labels = assign_smart_labels(marks, config.line_keys)
  local contents = {}
  local padding = config.label_padding or 1
  local padding_str = string.rep(" ", padding)

  -- First pass: calculate max width to determine alignment
  local max_content_width = 0
  local line_data = {}

  for i, mark in ipairs(marks) do
    local label = smart_labels[i] or " "
    local filename = utils.get_file_name(mark.filename)
    -- Format: [filename] [space] [padding][label][padding]
    local content_width = vim.fn.strwidth(filename)
      + 1
      + padding
      + #label
      + padding
    max_content_width = math.max(max_content_width, content_width)
    table.insert(line_data, {
      label = label,
      filename = filename,
      content_width = content_width,
    })
  end

  -- Add outer padding to total width (left padding only, no right padding)
  local total_width = padding + max_content_width

  -- Second pass: build right-aligned lines
  for i, data in ipairs(line_data) do
    local left_space = max_content_width - data.content_width
    -- Format: [padding][left_space][filename] [space] [padding][label][padding]
    local line = padding_str
      .. string.rep(" ", left_space)
      .. data.filename
      .. " "
      .. padding_str
      .. data.label
      .. padding_str
    contents[i] = line
  end

  vim.api.nvim_buf_set_option(Buffer_manager_bufh, "modifiable", true)
  vim.api.nvim_buf_set_lines(Buffer_manager_bufh, 0, -1, false, contents)
  vim.api.nvim_buf_set_option(Buffer_manager_bufh, "modifiable", false)

  -- Update window size based on content
  update_window_size(total_width, #marks)

  -- Set up extmarks for highlighting
  local ns_id = vim.api.nvim_create_namespace("BufferManagerLabel")
  vim.api.nvim_buf_clear_namespace(Buffer_manager_bufh, ns_id, 0, -1)

  for i, mark in ipairs(marks) do
    local label = smart_labels[i]
    local is_current = is_current_buffer(mark.buf_id)
    local is_active = is_buffer_active(mark.buf_id)
    local data = line_data[i]

    if label and label ~= " " then
      local left_space = max_content_width - data.content_width
      local filename_start = padding + left_space
      local filename_end = filename_start + vim.fn.strwidth(data.filename)
      local label_start = filename_end + 1 + padding -- after filename + space + padding
      local label_end = label_start + #label + padding -- label + right padding

      -- Determine highlight groups
      local label_hl = config.hl_label or "Search"
      local filename_hl

      if is_current then
        -- Current buffer in the focused window: use Bold
        filename_hl = config.hl_cursor or "Bold"
      elseif is_active then
        -- Active in other windows: use Normal (no special highlighting)
        filename_hl = config.hl_active or "Normal"
      else
        -- Not visible anywhere: use Comment
        filename_hl = config.hl_inactive or "Comment"
      end

      -- Highlight filename
      vim.api.nvim_buf_add_highlight(
        Buffer_manager_bufh,
        ns_id,
        filename_hl,
        i - 1,
        filename_start,
        filename_end
      )

      -- Highlight the label INCLUDING padding on both sides
      vim.api.nvim_buf_add_highlight(
        Buffer_manager_bufh,
        ns_id,
        label_hl,
        i - 1,
        label_start - padding,
        label_end
      )
    end
  end

  -- Set global selection mode keybindings
  set_selection_keybindings(smart_labels)
end

-- Close the menu completely
function M.close_menu()
  if
    Buffer_manager_win_id and vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    vim.api.nvim_win_close(Buffer_manager_win_id, true)
  end
  Buffer_manager_win_id = nil
  Buffer_manager_bufh = nil
  is_expanded = false
  clear_selection_keymaps()
end

-- Toggle menu (create or close)
function M.toggle_menu()
  log.trace("toggle_menu()")

  if
    Buffer_manager_win_id and vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    M.close_menu()
    return
  end

  -- Record last editor window
  local cur_win = vim.api.nvim_get_current_win()
  local cfg = vim.api.nvim_win_get_config(cur_win)
  if cfg.relative == "" then
    last_editor_win = cur_win
  else
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local c = vim.api.nvim_win_get_config(w)
      if c.relative == "" then
        last_editor_win = w
        break
      end
    end
  end

  update_marks()
  local total_buffers = #marks

  if total_buffers == 0 then
    vim.notify("[buffer_manager] No buffers to display", vim.log.levels.INFO)
    return
  end

  -- Create window with initial collapsed size
  -- width = 2 (for dash characters) + 2 * padding
  local padding = config.label_padding or 1
  local initial_width = 2 + 2 * padding
  local win_info = create_window(total_buffers, initial_width)
  Buffer_manager_win_id = win_info.win_id
  Buffer_manager_bufh = win_info.bufnr

  is_expanded = false
  render_collapsed()
end

-- Expand menu to show labels and names
function M.expand_menu()
  log.trace("expand_menu()")

  if
    not Buffer_manager_win_id
    or not vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    return
  end

  is_expanded = true
  render_expanded()
end

-- Collapse menu back to dashes
function M.collapse_menu()
  log.trace("collapse_menu()")

  if
    not Buffer_manager_win_id
    or not vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    return
  end

  is_expanded = false
  render_collapsed()
end

-- Select buffer by index
function M.select_buffer(idx)
  local mark = marks[idx]
  if not mark then return end

  -- Use the current window (which should be the window that had focus when menu was opened)
  local target_win = vim.api.nvim_get_current_win()
  
  -- If somehow we're in a floating window, find a real window
  if vim.api.nvim_win_get_config(target_win).relative ~= "" then
    target_win = last_editor_win and vim.api.nvim_win_is_valid(last_editor_win) 
      and last_editor_win 
      or find_main_window()
  end

  vim.api.nvim_set_current_win(target_win)

  -- Open buffer
  local bufnr = vim.fn.bufnr(mark.filename)
  if bufnr ~= -1 then
    vim.cmd("buffer " .. bufnr)
  else
    vim.cmd("edit " .. mark.filename)
  end

  -- Collapse back to dashes
  is_expanded = false
  render_collapsed()
end

-- Handle main keymap press
function M.handle_main_keymap()
  if
    Buffer_manager_win_id and vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    if is_expanded then
      -- Menu is expanded - pressing ";" again switches to last accessed buffer
      local last_buf = get_last_accessed_buffer()
      if last_buf then
        local buf_idx = get_buffer_index(last_buf)
        if buf_idx then
          M.select_buffer(buf_idx)
        end
      end
    else
      -- Menu is collapsed - expand it
      M.expand_menu()
    end
  else
    -- No menu open - create one
    M.toggle_menu()
  end
end

-- Refresh menu if open
function M.refresh_menu()
  if
    not Buffer_manager_win_id
    or not vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    return
  end

  update_marks()

  if #marks == 0 then
    M.close_menu()
    return
  end

  -- Re-render based on current state (collapsed or expanded)
  -- The render functions will handle resizing
  if is_expanded then
    render_expanded()
  else
    render_collapsed()
  end
end

return M
