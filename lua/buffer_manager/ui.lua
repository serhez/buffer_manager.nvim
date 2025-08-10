local Path = require("plenary.path")
local buffer_manager = require("buffer_manager")
local popup = require("plenary.popup")
local utils = require("buffer_manager.utils")
local log = require("buffer_manager.dev").log
local marks = require("buffer_manager").marks

local version_info = vim.inspect(vim.version())
local version_minor = tonumber(version_info:match("minor = (%d+)"))

local M = {}

Buffer_manager_win_id = nil
Buffer_manager_bufh = nil
-- Persistent menu state
Persistent_menu_win_id = nil
Persistent_menu_bufh = nil
local last_accessed_buffer = nil -- Last real buffer before current
local previous_buffer = nil      -- Second most recent real buffer (for toggle)
local last_editor_win = nil  -- Last non-menu editor window used for opening buffers
local initial_marks = {}
local config = buffer_manager.get_config()

-- Helper to apply horizontal movement restrictions without overriding active label keys
local function apply_horizontal_restrictions(bufnr, winid, active_labels)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end
  active_labels = active_labels or {}
  -- Candidate motion keys that could move horizontally or jump within line
  local candidates = { 'h','l','0','$','<Left>','<Right>','w','e','b','f','t','F','T','W','E','B' }
  for _, key in ipairs(candidates) do
    local plain = key:gsub('[<>]', '')
    if #plain == 1 and active_labels[plain] then
      -- Skip suppression to preserve label mapping
    else
      pcall(vim.api.nvim_buf_set_keymap, bufnr, 'n', key, '<Nop>', { silent = true })
    end
  end
  -- Lock cursor to column 1 (only create one autocmd per buffer)
  local ok, existing = pcall(vim.api.nvim_buf_get_var, bufnr, 'buffer_manager_lock_col')
  if not (ok and existing) then
    pcall(vim.api.nvim_buf_set_var, bufnr, 'buffer_manager_lock_col', true)
    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = bufnr,
      callback = function()
        if winid and vim.api.nvim_win_is_valid(winid) then
          local line = vim.api.nvim_win_get_cursor(winid)[1]
          vim.api.nvim_win_set_cursor(winid, { line, 1 })
        end
      end,
      desc = 'Keep cursor in column 1 for buffer_manager menu'
    })
  end
end

-- Buffer tracking functions
local function is_menu_buffer(bufnr)
  if not bufnr or bufnr < 1 then return false end
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, 'buffer_manager_menu')
  return ok and val == true
end

local function track_buffer_switch(new_buffer)
  -- Simple last-two real buffer tracking; caller passes the target buffer (real) about to be shown
  if not new_buffer or not vim.api.nvim_buf_is_valid(new_buffer) then return end
  if is_menu_buffer(new_buffer) then return end
  local current_buf = vim.api.nvim_get_current_buf()
  if current_buf == new_buffer then return end
  if not is_menu_buffer(current_buf) then
    -- Shift chain: previous becomes last_accessed, last_accessed becomes current
    previous_buffer = last_accessed_buffer
    last_accessed_buffer = current_buf
  end
end

local function get_alt_tab_buffer()
  local current_buf = vim.api.nvim_get_current_buf()
  -- If ordering is lastused and marks reflect that ordering, prefer the first different buffer in marks
  if config.order_buffers and config.order_buffers:match('lastused') then
    for i, mark in ipairs(marks) do
      if mark.buf_id ~= current_buf and vim.api.nvim_buf_is_valid(mark.buf_id) then
        return mark.buf_id
      end
      if i > 2 then break end -- Only need to scan top couple entries
    end
  end
  -- Fallback to tracked pair
  if last_accessed_buffer and vim.api.nvim_buf_is_valid(last_accessed_buffer) and last_accessed_buffer ~= current_buf then
    return last_accessed_buffer
  end
  if previous_buffer and vim.api.nvim_buf_is_valid(previous_buffer) and previous_buffer ~= current_buf then
    return previous_buffer
  end
  return nil
end

-- We save before we close because we use the state of the buffer as the list
-- of items.
local function close_menu(force_save)
  force_save = force_save or false

  vim.api.nvim_win_close(Buffer_manager_win_id, true)

  Buffer_manager_win_id = nil
  Buffer_manager_bufh = nil
end

local function create_window(actual_height)
  -- actual_height: optional override to use fewer lines than configured maximum

  log.trace("_create_window()")

  local width = require("buffer_manager").get_config().width
  local configured_height = require("buffer_manager").get_config().height
  local height = configured_height

  if config then
    if config.width ~= nil then
      if config.width <= 1 then
        local gwidth = vim.api.nvim_list_uis()[1].width
        width = math.floor(gwidth * config.width)
      else
        width = config.width
      end
    end

    if config.height ~= nil then
      if config.height <= 1 then
        local gheight = vim.api.nvim_list_uis()[1].height
        configured_height = math.floor(gheight * config.height)
      else
        configured_height = config.height
      end
    end
  end

  if actual_height and actual_height < configured_height then
    height = actual_height
  else
    height = configured_height
  end

  local borderchars = config.borderchars
  local bufnr = vim.api.nvim_create_buf(false, false)
  -- Tag as buffer_manager menu buffer early for autocmd exclusion
  pcall(vim.api.nvim_buf_set_var, bufnr, 'buffer_manager_menu', true)

  local win_config = {
    -- title = { { text = "Buffers", pos = "N" } },
    -- titlehighlight = "Search",
    -- titlepos = "center",
    line = math.floor(((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    cursorline = true,
    minwidth = width,
    minheight = height,
    borderchars = borderchars,
  }
  local Buffer_manager_win_id, win = popup.create(bufnr, win_config)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  if config.highlight ~= "" then
    vim.api.nvim_set_option_value(
      "winhighlight",
      config.highlight,
      { win = win.border.win_id }
    )
  end

  return {
    bufnr = bufnr,
    win_id = Buffer_manager_win_id,
  }
end

local function create_persistent_window(actual_height)
  -- actual_height: optional adaptive height
  log.trace("create_persistent_window()")

  local pconfig = config.persistent_menu
  local width = pconfig.width
  local configured_height = pconfig.height
  local height = configured_height
  if actual_height and actual_height < configured_height then
    height = actual_height
  end

  -- Calculate position based on config
  local ui_info = vim.api.nvim_list_uis()[1]
  local screen_width = ui_info.width
  local screen_height = ui_info.height

  local row, col
  if pconfig.position == "top-right" then
    row = pconfig.offset_y
    col = screen_width - width - pconfig.offset_x
  elseif pconfig.position == "top-left" then
    row = pconfig.offset_y
    col = pconfig.offset_x
  elseif pconfig.position == "bottom-right" then
    row = screen_height - height - pconfig.offset_y
    col = screen_width - width - pconfig.offset_x
  elseif pconfig.position == "bottom-left" then
    row = screen_height - height - pconfig.offset_y
    col = pconfig.offset_x
  else
    -- Default to top-right
    row = pconfig.offset_y
    col = screen_width - width - pconfig.offset_x
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  -- Tag as buffer_manager persistent menu buffer for autocmd exclusion
  pcall(vim.api.nvim_buf_set_var, bufnr, 'buffer_manager_menu', true)

  local win_config = {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "none",
    focusable = true,
  }

  local win_id = vim.api.nvim_open_win(bufnr, false, win_config)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)

  -- Set window options
  vim.api.nvim_win_set_option(win_id, "wrap", false)
  vim.api.nvim_win_set_option(win_id, "cursorline", true)

  return {
    bufnr = bufnr,
    win_id = win_id,
  }
end

local function string_starts(string, start)
  return string.sub(string, 1, string.len(start)) == start
end

local function string_ends(string, ending)
  return ending == "" or string.sub(string, -string.len(ending)) == ending
end

local function can_be_deleted(bufname, bufnr)
  return (
    vim.api.nvim_buf_is_valid(bufnr)
    and (not string_starts(bufname, "term://"))
    and not vim.bo[bufnr].modified
    and bufnr ~= -1
  )
end

local function assign_smart_labels(buffers, available_keys)
  local label_assignment = {}
  local used_labels = {}

  -- Phase 1: Try to match each buffer to the first alphanumeric (letter or digit)
  -- character in its filename (ignoring leading dots/underscores and other symbols).
  -- Examples:
  --   .env        -> e
  --   __init__.py -> i
  --   .123config  -> 1
  --   foo.lua     -> f
  for i, mark in ipairs(buffers) do
    if i > #available_keys then
      break -- Don't assign more labels than available
    end

    local filename = utils.get_file_name(mark.filename)
    -- Find first alphanumeric; pattern [%w] matches [0-9A-Za-z]
    local first_alnum = filename:match("[%w]")

    if first_alnum then
      local key_candidate = string.lower(first_alnum)
      if vim.tbl_contains(available_keys, key_candidate) and not used_labels[key_candidate] then
        label_assignment[i] = key_candidate
        used_labels[key_candidate] = true
      end
    end
  end

  -- Phase 2: Assign remaining available labels to buffers without labels
  local available_label_idx = 1
  for i, _ in ipairs(buffers) do
    if i > #available_keys then
      break -- Don't assign more labels than available
    end

    if not label_assignment[i] then
      -- Find next available label
      while available_label_idx <= #available_keys do
        local label = available_keys[available_label_idx]
        available_label_idx = available_label_idx + 1

        if not used_labels[label] then
          label_assignment[i] = label
          used_labels[label] = true
          break
        end
      end
    end
  end

  return label_assignment
end

local function is_buffer_in_marks(bufnr)
  for _, mark in pairs(marks) do
    if mark.buf_id == bufnr then
      return true
    end
  end
  return false
end

local function update_buffers()
  -- Check deletions
  for _, mark in pairs(initial_marks) do
    if not is_buffer_in_marks(mark.buf_id) then
      if can_be_deleted(mark.filename, mark.buf_id) then
        vim.api.nvim_buf_clear_namespace(mark.buf_id, -1, 1, -1)
        vim.api.nvim_buf_delete(mark.buf_id, {})
      end
    end
  end

  -- Check additions
  for idx, mark in pairs(marks) do
    local bufnr = vim.fn.bufnr(mark.filename)
    -- Add buffer only if it does not already exist or if it is not listed
    if bufnr == -1 or vim.fn.buflisted(bufnr) ~= 1 then
      vim.cmd("badd " .. mark.filename)
      marks[idx].buf_id = vim.fn.bufnr(mark.filename)
    end
  end
end

local function remove_mark(idx)
  marks[idx] = nil
  if idx < #marks then
    for i = idx, #marks do
      marks[i] = marks[i + 1]
    end
  end
end

local function order_buffers()
  if string_starts(config.order_buffers, "filename") then
    table.sort(marks, function(a, b)
      local a_name = string.lower(utils.get_file_name(a.filename))
      local b_name = string.lower(utils.get_file_name(b.filename))
      return a_name < b_name
    end)
  elseif string_starts(config.order_buffers, "fullpath") then
    table.sort(marks, function(a, b)
      local a_name = string.lower(a.filename)
      local b_name = string.lower(b.filename)
      return a_name < b_name
    end)
  elseif string_starts(config.order_buffers, "bufnr") then
    table.sort(marks, function(a, b)
      return a.buf_id < b.buf_id
    end)
  elseif string_starts(config.order_buffers, "lastused") then
    table.sort(marks, function(a, b)
      local a_lastused = vim.fn.getbufinfo(a.buf_id)[1].lastused
      local b_lastused = vim.fn.getbufinfo(b.buf_id)[1].lastused
      if a_lastused == b_lastused then
        return a.buf_id < b.buf_id
      else
        return a_lastused > b_lastused
      end
    end)
  end
  if string_ends(config.order_buffers, "reverse") then
    -- Reverse the order of the marks
    local reversed_marks = {}
    for i = #marks, 1, -1 do
      table.insert(reversed_marks, marks[i])
    end
    marks = reversed_marks
  end
end

local function update_marks()
  -- Check if any buffer has been deleted
  -- If so, remove it from marks
  for idx, mark in pairs(marks) do
    if not utils.buffer_is_valid(mark.buf_id, mark.filename) then
      remove_mark(idx)
    end
  end

  -- Check if any buffer has been added
  -- If so, add it to marks
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    if utils.buffer_is_valid(buf, bufname) and not is_buffer_in_marks(buf) then
      table.insert(marks, {
        filename = bufname,
        buf_id = buf,
      })
    end
  end

  -- Order the buffers, if the option is set
  if config.order_buffers then
    order_buffers()
  end
end

local function set_menu_keybindings(smart_labels)
  vim.api.nvim_buf_set_keymap(
    Buffer_manager_bufh,
    "n",
    "q",
    "<Cmd>lua require('buffer_manager.ui').toggle_quick_menu()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    Buffer_manager_bufh,
    "n",
    "<ESC>",
    "<Cmd>lua require('buffer_manager.ui').toggle_quick_menu()<CR>",
    { silent = true }
  )

  -- Add main keymap for last buffer navigation
  if config.main_keymap and config.main_keymap ~= "" then
    vim.api.nvim_buf_set_keymap(
      Buffer_manager_bufh,
      "n",
      config.main_keymap,
      "<Cmd>lua require('buffer_manager.ui').nav_to_last_buffer_from_quick()<CR>",
      { silent = true }
    )
  end

  for _, value in pairs(config.select_menu_item_commands) do
    vim.api.nvim_buf_set_keymap(
      Buffer_manager_bufh,
      "n",
      value.key,
      "<Cmd>lua require('buffer_manager.ui').select_menu_item('"
        .. value.command
        .. "')<CR>",
      {}
    )
  end
  vim.cmd(
    string.format(
      "autocmd BufModifiedSet <buffer=%s> set nomodified",
      Buffer_manager_bufh
    )
  )
  vim.cmd(
    "autocmd BufLeave <buffer> ++nested ++once silent"
      .. " lua require('buffer_manager.ui').toggle_quick_menu()"
  )
  vim.cmd(
    string.format(
      "autocmd BufWriteCmd <buffer=%s>"
        .. " lua require('buffer_manager.ui').on_menu_save()",
      Buffer_manager_bufh
    )
  )
  -- Go to file hitting its line number or smart label
  if smart_labels then
    for i, label in pairs(smart_labels) do
      if label and label ~= " " then
        vim.api.nvim_buf_set_keymap(
          Buffer_manager_bufh,
          "n",
          label,
          string.format(
            "<Cmd>%s <bar> lua require('buffer_manager.ui')"
              .. ".select_menu_item()<CR>",
            i
          ),
          {}
        )
      end
    end
  else
    -- Fallback to original behavior
    local keys = config.line_keys
    for i = 1, #keys do
      local c = keys[i]
      vim.api.nvim_buf_set_keymap(
        Buffer_manager_bufh,
        "n",
        c,
        string.format(
          "<Cmd>%s <bar> lua require('buffer_manager.ui')"
            .. ".select_menu_item()<CR>",
          i
        ),
        {}
      )
    end
  end
end

local function set_win_buf_options(contents, current_buf_line)
  vim.api.nvim_set_option_value(
    "number",
    false,
    { win = Buffer_manager_win_id }
  )
  for key, value in pairs(config.win_extra_options) do
    vim.api.nvim_set_option_value(key, value, { win = Buffer_manager_win_id })
  end
  -- Assign a unique buffer name to avoid E95 (duplicate buffer name)
  local base_name = "Buffers"
  local unique_name = base_name
  local counter = 1
  while vim.fn.bufnr(unique_name) ~= -1 and vim.fn.bufnr(unique_name) ~= Buffer_manager_bufh do
    counter = counter + 1
    unique_name = base_name .. "_" .. counter
  end
  pcall(vim.api.nvim_buf_set_name, Buffer_manager_bufh, unique_name)
  vim.api.nvim_buf_set_option(Buffer_manager_bufh, "modifiable", true)
  vim.api.nvim_buf_set_lines(Buffer_manager_bufh, 0, #contents, false, contents)
  vim.api.nvim_buf_set_option(Buffer_manager_bufh, "modifiable", false)

  -- Set functions depending on Neovim version
  if version_minor > 9 then
    vim.api.nvim_set_option_value(
      "filetype",
      "buffer_manager",
      { buf = Buffer_manager_bufh }
    )
    vim.api.nvim_set_option_value(
      "buftype",
      "acwrite",
      { buf = Buffer_manager_bufh }
    )
    vim.api.nvim_set_option_value(
      "bufhidden",
      "delete",
      { buf = Buffer_manager_bufh }
    )
  else
    vim.api.nvim_buf_set_option(
      Buffer_manager_bufh,
      "filetype",
      "buffer_manager"
    )
    vim.api.nvim_buf_set_option(Buffer_manager_bufh, "buftype", "acwrite")
    vim.api.nvim_buf_set_option(Buffer_manager_bufh, "bufhidden", "delete")
  end
  vim.cmd(string.format(":call cursor(%d, %d)", current_buf_line, 1))
end

function M.handle_main_keymap()
  log.trace("handle_main_keymap()")

  -- Check if persistent menu is open
  if
    Persistent_menu_win_id and vim.api.nvim_win_is_valid(Persistent_menu_win_id)
  then
    -- Persistent menu is open, check if it's focused
    local current_win = vim.api.nvim_get_current_win()
    if current_win == Persistent_menu_win_id then
      -- Persistent menu is focused - navigate to last buffer and unfocus
      M.nav_to_last_buffer_from_persistent()
    else
      -- Persistent menu is open but not focused - capture current editor window then focus menu
      local cfg = vim.api.nvim_win_get_config(current_win)
      if cfg.relative == '' then
        last_editor_win = current_win
      end
      vim.api.nvim_set_current_win(Persistent_menu_win_id)
    end
    return
  end

  -- No persistent menu open, open the quick menu
  M.toggle_quick_menu()
end

function M.toggle_quick_menu(adaptive_height)
  -- adaptive_height is ignored externally; we compute it from buffer count
  -- Record last editor window before opening
  if not (Buffer_manager_win_id and vim.api.nvim_win_is_valid(Buffer_manager_win_id)) then
    local cur_win = vim.api.nvim_get_current_win()
    local cfg = vim.api.nvim_win_get_config(cur_win)
    if cfg.relative == '' then
      last_editor_win = cur_win
    else
      -- Find a standard window
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == '' then last_editor_win = w; break end
      end
    end
  end
  log.trace("toggle_quick_menu()")
  if
    Buffer_manager_win_id ~= nil
    and vim.api.nvim_win_is_valid(Buffer_manager_win_id)
  then
    if vim.api.nvim_buf_get_changedtick(vim.fn.bufnr()) > 0 then
      M.on_menu_save()
    end
    close_menu(true)
    update_buffers()
    return
  end
  local current_buf_id = -1
  if config.focus_alternate_buffer then
    current_buf_id = vim.fn.bufnr("#")
  else
    current_buf_id = vim.fn.bufnr()
  end

  -- Determine adaptive height: min(#buffers, config.height)
  update_marks()
  local total_buffers = #marks
  if total_buffers == 0 then
    vim.notify('[buffer_manager] No buffers to display', vim.log.levels.INFO)
    return
  end
  local max_height = config.height or 10
  local adaptive_height_val = math.min(total_buffers, max_height)
  local win_info = create_window(adaptive_height_val)
  local contents = {}
  local extmark_contents = {}
  initial_marks = {}

  Buffer_manager_win_id = win_info.win_id
  Buffer_manager_bufh = win_info.bufnr

  update_marks()

  -- set initial_marks
  local current_buf_line = 1
  local line = 1
  local valid_marks = {}
  
  -- First, collect all valid marks
  for idx, mark in pairs(marks) do
    -- Add buffer only if it does not already exist
    if vim.fn.buflisted(mark.buf_id) ~= 1 then
      marks[idx] = nil
    else
      table.insert(valid_marks, {
        mark = marks[idx],
        original_idx = idx
      })
      initial_marks[idx] = {
        filename = marks[idx].filename,
        buf_id = marks[idx].buf_id,
      }
    end
  end
  
  -- Generate smart label assignments
  local smart_labels = assign_smart_labels(
    vim.tbl_map(function(item) return item.mark end, valid_marks),
    config.line_keys
  )
  
  for i, item in ipairs(valid_marks) do
    local current_mark = item.mark
    if current_mark.buf_id == current_buf_id then
      current_buf_line = line
    end
    local display_filename = current_mark.filename
    local display_path = ""
    if not string_starts(display_filename, "term://") then
      display_filename, display_path =
        utils.get_short_file_name(config, display_filename)
    else
      display_filename = utils.get_short_term_name(display_filename)
    end
    extmark_contents[line] = { display_filename, display_path }

    local line_key = smart_labels[i] or " "
    contents[line] = "   "
      .. line_key
      .. "   "
      .. display_filename
      .. display_path
    line = line + 1
  end

  set_win_buf_options(contents, current_buf_line)
  set_menu_keybindings(smart_labels)

  -- Apply horizontal movement restrictions (after keybindings so labels are preserved)
  local active_labels_set = {}
  if smart_labels then
    for _, lbl in pairs(smart_labels) do if lbl and lbl ~= ' ' then active_labels_set[lbl] = true end end
  else
    for _, lbl in ipairs(config.line_keys) do active_labels_set[lbl] = true end
  end
  apply_horizontal_restrictions(Buffer_manager_bufh, Buffer_manager_win_id, active_labels_set)

  -- Show the keys with extmarks
  local ns_id = vim.api.nvim_create_namespace("BufferManagerIndicator")
  for i = 1, #valid_marks do
    local key = smart_labels[i] or " "
    vim.api.nvim_buf_set_extmark(Buffer_manager_bufh, ns_id, i - 1, 0, {
      undo_restore = false,
      invalidate = true,
      conceal = "",
      virt_text = {
        { "  ", "FloatNormal" },
        { " " .. key .. " ", "Search" },
        { "  ", "FloatNormal" },
        { extmark_contents[i][1] or "", config.hl_filename or "Bold" },
        { extmark_contents[i][2] or "", config.hl_path or "Comment" },
      },
      virt_text_pos = "overlay",
      hl_mode = "combine",
      cursorline_hl_group = "CursorLine",
    })
  end
end

function M.select_menu_item(command)
  local idx = vim.fn.line(".")
  if vim.api.nvim_buf_get_changedtick(vim.fn.bufnr()) > 0 then
    M.on_menu_save()
  end
  close_menu(true)
  -- Use last_editor_win if valid
  if last_editor_win and vim.api.nvim_win_is_valid(last_editor_win) then
    pcall(vim.api.nvim_set_current_win, last_editor_win)
  end
  M.nav_file(idx, command)
  update_buffers()
end

function M.on_menu_save()
  log.trace("on_menu_save()")
  -- TODO: save marked buffers
end

function M.nav_file(id, command)
  log.trace("nav_file(): Navigating to", id)
  update_marks()

  local mark = marks[id]
  if not mark then
    return
  end

  -- Track current buffer before switching
  track_buffer_switch(mark.buf_id)

  if command == nil or command == "edit" then
    local bufnr = vim.fn.bufnr(mark.filename)
    -- Check if buffer exists by filename
    if bufnr ~= -1 then
      vim.cmd("buffer " .. bufnr)
    else
      vim.cmd("edit " .. mark.filename)
    end
  else
    vim.cmd(command .. " " .. mark.filename)
  end
end

local function get_current_buf_line()
  local current_buf_id = vim.fn.bufnr()
  for idx, mark in pairs(marks) do
    if mark.buf_id == current_buf_id then
      return idx
    end
  end
  log.error("get_current_buf_line(): Could not find current buffer in marks")
  return -1
end

function M.nav_next()
  log.trace("nav_next()")
  update_marks()
  local current_buf_line = get_current_buf_line()
  if current_buf_line == -1 then
    return
  end
  local next_buf_line = current_buf_line + 1
  if next_buf_line > #marks then
    if config.loop_nav then
      M.nav_file(1)
    end
  else
    M.nav_file(next_buf_line)
  end
end

function M.nav_prev()
  log.trace("nav_prev()")
  update_marks()
  local current_buf_line = get_current_buf_line()
  if current_buf_line == -1 then
    return
  end
  local prev_buf_line = current_buf_line - 1
  if prev_buf_line < 1 then
    if config.loop_nav then
      M.nav_file(#marks)
    end
  else
    M.nav_file(prev_buf_line)
  end
end

function M.location_window(options)
  local default_options = {
    relative = "editor",
    style = "minimal",
    width = options.width,
    height = options.height,
    row = 2,
    col = 2,
  }
  options = vim.tbl_extend("keep", options, default_options)

  local bufnr = options.bufnr or vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(bufnr, true, options)

  return {
    bufnr = bufnr,
    win_id = win_id,
  }
end

-- TODO: save the marked buffers (the ones we do not delete if too many buffers are open)
function M.save_menu_to_file(filename)
  log.trace("save_menu_to_file()")
  if filename == nil or filename == "" then
    filename = vim.fn.input("Enter filename: ")
    if filename == "" then
      return
    end
  end
  local file = io.open(filename, "w")
  if file == nil then
    log.error("save_menu_to_file(): Could not open file for writing")
    return
  end
  for _, mark in pairs(marks) do
    file:write(Path:new(mark.filename):absolute() .. "\n")
  end
  file:close()
  update_buffers()
end

local function close_persistent_menu()
  if
    Persistent_menu_win_id and vim.api.nvim_win_is_valid(Persistent_menu_win_id)
  then
    vim.api.nvim_win_close(Persistent_menu_win_id, true)
  end
  Persistent_menu_win_id = nil
  Persistent_menu_bufh = nil
end

local function set_persistent_menu_keybindings(smart_labels)
  -- Set up key mappings for selecting buffers
  if smart_labels then
    for i, label in pairs(smart_labels) do
      if label and label ~= " " then
        vim.api.nvim_buf_set_keymap(
          Persistent_menu_bufh,
          "n",
          label,
          string.format(
            "<Cmd>lua require('buffer_manager.ui').select_persistent_buffer(%d)<CR>",
            i
          ),
          { silent = true }
        )
      end
    end
  else
    -- Fallback to original behavior
    local keys = config.line_keys
    for i = 1, #keys do
      local key = keys[i]
      vim.api.nvim_buf_set_keymap(
        Persistent_menu_bufh,
        "n",
        key,
        string.format(
          "<Cmd>lua require('buffer_manager.ui').select_persistent_buffer(%d)<CR>",
          i
        ),
        { silent = true }
      )
    end
  end

  -- Add Enter key support (same as quick menu)
  for _, value in pairs(config.select_menu_item_commands) do
    vim.api.nvim_buf_set_keymap(
      Persistent_menu_bufh,
      "n",
      value.key,
      "<Cmd>lua require('buffer_manager.ui').select_persistent_menu_item('"
        .. value.command
        .. "')<CR>",
      { silent = true }
    )
  end

  -- Add main keymap for last buffer navigation
  if config.main_keymap and config.main_keymap ~= "" then
    vim.api.nvim_buf_set_keymap(
      Persistent_menu_bufh,
      "n",
      config.main_keymap,
      "<Cmd>lua require('buffer_manager.ui').nav_to_last_buffer_from_persistent()<CR>",
      { silent = true }
    )
  end

  -- Close on escape
  vim.api.nvim_buf_set_keymap(
    Persistent_menu_bufh,
    "n",
    "<ESC>",
    "<Cmd>lua require('buffer_manager.ui').toggle_persistent_menu()<CR>",
    { silent = true }
  )

  -- Close on q
  vim.api.nvim_buf_set_keymap(
    Persistent_menu_bufh,
    "n",
    "q",
    "<Cmd>lua require('buffer_manager.ui').toggle_persistent_menu()<CR>",
    { silent = true }
  )
end

local function find_main_window()
  -- Find the main content window (not floating, not our popups)
  local current_win = vim.api.nvim_get_current_win()
  local win_config = vim.api.nvim_win_get_config(current_win)

  -- If current window is not floating, use it
  if win_config.relative == "" then
    return current_win
  end

  -- Find the first non-floating window
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win_id)
    if cfg.relative == "" then
      return win_id
    end
  end

  -- Fallback to current window
  return current_win
end

function M.select_persistent_buffer(idx)
  log.trace("select_persistent_buffer(): Selecting buffer", idx)

  local mark = marks[idx]
  if not mark then
    return
  end

  -- Track current buffer before switching
  track_buffer_switch(mark.buf_id)

  -- Prefer last_editor_win if valid
  local target_win = (last_editor_win and vim.api.nvim_win_is_valid(last_editor_win)) and last_editor_win or find_main_window()

  -- If current window is the persistent menu, preserve previously stored last_editor_win; otherwise update it
  local cur_win = vim.api.nvim_get_current_win()
  if cur_win ~= Persistent_menu_win_id then
    local cfg = vim.api.nvim_win_get_config(cur_win)
    if cfg.relative == '' then
      last_editor_win = cur_win
    end
  end
  vim.api.nvim_set_current_win(target_win)
 
  -- Keep persistent menu open (do not close) to preserve persistence
  -- Switch focus to target window  -- Open the buffer
  local bufnr = vim.fn.bufnr(mark.filename)
  if bufnr ~= -1 then
    vim.cmd("buffer " .. bufnr)
  else
    vim.cmd("edit " .. mark.filename)
  end
  -- Return focus to persistent menu if desired config (optional future toggle)
end

function M.select_persistent_menu_item(command)
  log.trace(
    "select_persistent_menu_item(): Selecting item with command",
    command
  )

  local idx = vim.fn.line(".")
  local mark = marks[idx]
  if not mark then
    return
  end

  -- Track current buffer before switching
  track_buffer_switch(mark.buf_id)

  local target_win = (last_editor_win and vim.api.nvim_win_is_valid(last_editor_win)) and last_editor_win or find_main_window()
  -- If current window is not the persistent menu (rare here) and is a real editor window, update last_editor_win
  local cur_win = vim.api.nvim_get_current_win()
  if cur_win ~= Persistent_menu_win_id then
    local cfg = vim.api.nvim_win_get_config(cur_win)
    if cfg.relative == '' then last_editor_win = cur_win end
  end
  vim.api.nvim_set_current_win(target_win)
 
  -- Keep persistent menu open (do not close)
  -- Open the buffer with the specified command
  if command == nil or command == "edit" then
    local bufnr = vim.fn.bufnr(mark.filename)
    if bufnr ~= -1 then
      vim.cmd("buffer " .. bufnr)
    else
      vim.cmd("edit " .. mark.filename)
    end
  else
    vim.cmd(command .. " " .. mark.filename)
  end
  -- Optionally could refocus persistent menu window if user preference (not implemented)
end

local _alt_tab_flip = false
function M.nav_to_last_buffer_from_persistent()
  log.trace("nav_to_last_buffer_from_persistent()")
  -- Updated simplified behavior:
  -- When main_keymap is pressed while persistent menu is focused,
  -- select the SECOND buffer in the list (marks[2]) if it exists and is not the
  -- current buffer. If marks[2] is invalid or is the current buffer, fall back to
  -- the first other valid buffer in the list.
  -- Keep the persistent menu open; no toggle logic.

  update_marks()
  local current_buf = vim.api.nvim_get_current_buf()

  local target_win = (last_editor_win and vim.api.nvim_win_is_valid(last_editor_win)) and last_editor_win or find_main_window()

  local candidate = nil
  -- Prefer second buffer
  if marks[2] and vim.api.nvim_buf_is_valid(marks[2].buf_id) and marks[2].buf_id ~= current_buf then
    candidate = marks[2].buf_id
  else
    -- Fallback: find first different valid buffer (skipping the current)
    for _, mark in ipairs(marks) do
      if mark.buf_id ~= current_buf and vim.api.nvim_buf_is_valid(mark.buf_id) then
        candidate = mark.buf_id
        break
      end
    end
  end

  if not candidate then
    -- Nothing to switch to (only one buffer or none)
    pcall(vim.api.nvim_set_current_win, target_win)
    return
  end

  track_buffer_switch(candidate)
  pcall(vim.api.nvim_set_current_win, target_win)
  vim.cmd('buffer ' .. candidate)
end

function M.nav_to_last_buffer_from_quick()
  log.trace("nav_to_last_buffer_from_quick()")
  update_marks()
  local current_buf = vim.api.nvim_get_current_buf()
  local target_win = (last_editor_win and vim.api.nvim_win_is_valid(last_editor_win)) and last_editor_win or nil

  local target_buffer = get_alt_tab_buffer()
  if not target_buffer then
    -- Try toggle pair logic mirroring persistent variant
    if _alt_tab_flip then
      if previous_buffer and vim.api.nvim_buf_is_valid(previous_buffer) and previous_buffer ~= current_buf then
        target_buffer = previous_buffer
      end
    else
      if last_accessed_buffer and vim.api.nvim_buf_is_valid(last_accessed_buffer) and last_accessed_buffer ~= current_buf then
        target_buffer = last_accessed_buffer
      elseif previous_buffer and vim.api.nvim_buf_is_valid(previous_buffer) and previous_buffer ~= current_buf then
        target_buffer = previous_buffer
      end
    end
  end

  close_menu(true)
  if target_buffer then
    track_buffer_switch(target_buffer)
    if target_win then pcall(vim.api.nvim_set_current_win, target_win) end
    vim.cmd('buffer ' .. target_buffer)
    _alt_tab_flip = not _alt_tab_flip
  else
    if target_win then pcall(vim.api.nvim_set_current_win, target_win) end
  end
  update_buffers()
end

function M.toggle_persistent_menu(adaptive_height)
  -- adaptive_height is ignored externally; we compute from buffer count
  log.trace("toggle_persistent_menu()")

  -- If menu is open, close it
  if
    Persistent_menu_win_id and vim.api.nvim_win_is_valid(Persistent_menu_win_id)
  then
    close_persistent_menu()
    return
  end

  -- Record last editor window before opening (similar to quick menu)
  if not (Persistent_menu_win_id and vim.api.nvim_win_is_valid(Persistent_menu_win_id)) then
    local cur_win = vim.api.nvim_get_current_win()
    local cfg = vim.api.nvim_win_get_config(cur_win)
    if cfg.relative == '' then
      last_editor_win = cur_win
    else
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == '' then last_editor_win = w; break end
      end
    end
  end

  -- Update marks to get current buffers (before sizing)
  update_marks()
  local total_buffers = #marks
  if total_buffers == 0 then
    vim.notify('[buffer_manager] No buffers to display', vim.log.levels.INFO)
    return
  end
  local max_height = (config.persistent_menu and config.persistent_menu.height) or 15
  local adaptive_height_val = math.min(total_buffers, max_height)

  -- Create the persistent window with adaptive height
  local win_info = create_persistent_window(adaptive_height_val)
  Persistent_menu_win_id = win_info.win_id
  Persistent_menu_bufh = win_info.bufnr

  -- Generate content for persistent menu (filenames only)
  local contents = {}
  local extmark_contents = {}
  local valid_marks = {}

  -- Collect valid marks
  for i, mark in pairs(marks) do
    if i <= #config.line_keys then
      table.insert(valid_marks, mark)
    else
      break -- Don't show more buffers than we have keys
    end
  end
  
  -- Generate smart label assignments for persistent menu
  local smart_labels = assign_smart_labels(valid_marks, config.line_keys)

  for i, mark in ipairs(valid_marks) do
    local display_filename = mark.filename
    if not string_starts(display_filename, "term://") then
      display_filename = utils.get_file_name(mark.filename) -- Just filename, no path
    else
      display_filename = utils.get_short_term_name(display_filename)
    end

    extmark_contents[i] = { display_filename, "" } -- No path for persistent menu

    local line_key = smart_labels[i] or " "
    contents[i] = "   " .. line_key .. "   " .. display_filename
  end

  -- Set buffer content
  vim.api.nvim_buf_set_option(Persistent_menu_bufh, "modifiable", true)
  vim.api.nvim_buf_set_lines(Persistent_menu_bufh, 0, -1, false, contents)
  vim.api.nvim_buf_set_option(Persistent_menu_bufh, "modifiable", false)

  -- Set up keybindings (only for when the persistent menu is focused)
  set_persistent_menu_keybindings(smart_labels)

  -- Apply horizontal restrictions (respect active labels)
  local active_labels_set = {}
  if smart_labels then
    for _, lbl in pairs(smart_labels) do if lbl and lbl ~= ' ' then active_labels_set[lbl] = true end end
  else
    for _, lbl in ipairs(config.line_keys) do active_labels_set[lbl] = true end
  end
  apply_horizontal_restrictions(Persistent_menu_bufh, Persistent_menu_win_id, active_labels_set)

  -- Show the keys with extmarks
  local ns_id =
    vim.api.nvim_create_namespace("BufferManagerPersistentIndicator")
  for i = 1, #valid_marks do
    local key = smart_labels[i] or " "
    vim.api.nvim_buf_set_extmark(Persistent_menu_bufh, ns_id, i - 1, 0, {
      undo_restore = false,
      invalidate = true,
      conceal = "",
      virt_text = {
        { "  ", "FloatNormal" },
        { " " .. key .. " ", "Search" },
        { "  ", "FloatNormal" },
        { extmark_contents[i][1] or "", config.hl_filename or "Bold" },
      },
      virt_text_pos = "overlay",
      hl_mode = "combine",
      cursorline_hl_group = "CursorLine",
    })
  end
end

-- Refresh logic for persistent and quick menus
local _refreshing = false

function M.refresh_persistent_menu()
  if _refreshing then return end
  if not (Persistent_menu_win_id and vim.api.nvim_win_is_valid(Persistent_menu_win_id)) then
    return -- Nothing to do
  end
  if Persistent_menu_bufh and vim.api.nvim_buf_is_valid(Persistent_menu_bufh) then
    local ok, is_menu = pcall(vim.api.nvim_buf_get_var, Persistent_menu_bufh, 'buffer_manager_menu')
    if not (ok and is_menu) then
      -- Not tagged as menu? Tag it to prevent external refresh loops
      pcall(vim.api.nvim_buf_set_var, Persistent_menu_bufh, 'buffer_manager_menu', true)
    end
  end
  _refreshing = true
  pcall(function()
    -- Recompute marks
    update_marks()
    local total_buffers = #marks
    if total_buffers == 0 then
      -- Close if no buffers remain
      close_persistent_menu()
      vim.notify('[buffer_manager] No buffers to display', vim.log.levels.INFO)
      return
    end

    -- Determine desired height (adaptive)
    local max_height = (config.persistent_menu and config.persistent_menu.height) or 15
    local desired_height = math.min(total_buffers, max_height, #config.line_keys)

    -- Trim list of marks to number of available keys for display
    local valid_marks = {}
    for i, mark in ipairs(marks) do
      if i > #config.line_keys then break end
      table.insert(valid_marks, mark)
    end

    -- Generate smart labels
    local smart_labels = assign_smart_labels(valid_marks, config.line_keys)

    -- Build contents
    local contents = {}
    local extmark_contents = {}
    for i, mark in ipairs(valid_marks) do
      local display_filename = mark.filename
      if not string_starts(display_filename, 'term://') then
        display_filename = utils.get_file_name(mark.filename)
      else
        display_filename = utils.get_short_term_name(display_filename)
      end
      extmark_contents[i] = { display_filename, '' }
      local line_key = smart_labels[i] or ' '
      contents[i] = '   ' .. line_key .. '   ' .. display_filename
    end

    -- Resize window if needed
    local win_cfg = vim.api.nvim_win_get_config(Persistent_menu_win_id)
    if win_cfg.height ~= desired_height then
      win_cfg.height = desired_height
      pcall(vim.api.nvim_win_set_config, Persistent_menu_win_id, win_cfg)
    end

    -- Replace buffer lines
    if Persistent_menu_bufh and vim.api.nvim_buf_is_valid(Persistent_menu_bufh) then
      vim.api.nvim_buf_set_option(Persistent_menu_bufh, 'modifiable', true)
      vim.api.nvim_buf_set_lines(Persistent_menu_bufh, 0, -1, false, contents)
      vim.api.nvim_buf_set_option(Persistent_menu_bufh, 'modifiable', false)
      -- Clear old extmarks namespace (safe even if missing)
      local ns_id = vim.api.nvim_create_namespace('BufferManagerPersistentIndicator')
      pcall(vim.api.nvim_buf_clear_namespace, Persistent_menu_bufh, ns_id, 0, -1)
      for i = 1, #valid_marks do
        local key = smart_labels[i] or ' '
        vim.api.nvim_buf_set_extmark(Persistent_menu_bufh, ns_id, i - 1, 0, {
          undo_restore = false,
          invalidate = true,
          conceal = '',
          virt_text = {
            { '  ', 'FloatNormal' },
            { ' ' .. key .. ' ', 'Search' },
            { '  ', 'FloatNormal' },
            { extmark_contents[i][1] or '', config.hl_filename or 'Bold' },
          },
          virt_text_pos = 'overlay',
          hl_mode = 'combine',
          cursorline_hl_group = 'CursorLine',
        })
      end
      -- Reapply keymaps (buffer was reused; clear existing maps could be done, but re-setting is fine)
      set_persistent_menu_keybindings(smart_labels)
      -- Reapply horizontal movement restrictions respecting active labels
      local active_labels_set = {}
      if smart_labels then
        for _, lbl in pairs(smart_labels) do if lbl and lbl ~= ' ' then active_labels_set[lbl] = true end end
      else
        for _, lbl in ipairs(config.line_keys) do active_labels_set[lbl] = true end
      end
      apply_horizontal_restrictions(Persistent_menu_bufh, Persistent_menu_win_id, active_labels_set)
    end
  end)
  _refreshing = false
end

function M.refresh_quick_menu_if_open()
  if _refreshing then return end
  if not (Buffer_manager_win_id and vim.api.nvim_win_is_valid(Buffer_manager_win_id)) then
    return
  end
  if Buffer_manager_bufh and vim.api.nvim_buf_is_valid(Buffer_manager_bufh) then
    local ok, is_menu = pcall(vim.api.nvim_buf_get_var, Buffer_manager_bufh, 'buffer_manager_menu')
    if not (ok and is_menu) then
      pcall(vim.api.nvim_buf_set_var, Buffer_manager_bufh, 'buffer_manager_menu', true)
    end
  end
  _refreshing = true
  pcall(function()
    update_marks()
    local total_buffers = #marks
    if total_buffers == 0 then
      close_menu(true)
      return
    end
    local max_height = config.height or 10
    local desired_height = math.min(total_buffers, max_height)

    -- Gather valid marks for display
    local valid_marks = {}
    for idx, mark in ipairs(marks) do
      table.insert(valid_marks, { mark = mark, original_idx = idx })
    end

    local smart_labels = assign_smart_labels(vim.tbl_map(function(item) return item.mark end, valid_marks), config.line_keys)

    local contents = {}
    local extmark_contents = {}
    local current_buf_id = vim.fn.bufnr()
    local current_buf_line = 1
    local line = 1

    for i, item in ipairs(valid_marks) do
      local current_mark = item.mark
      if current_mark.buf_id == current_buf_id then
        current_buf_line = line
      end
      local display_filename = current_mark.filename
      local display_path = ''
      if not string_starts(display_filename, 'term://') then
        display_filename, display_path = utils.get_short_file_name(config, display_filename)
      else
        display_filename = utils.get_short_term_name(display_filename)
      end
      extmark_contents[line] = { display_filename, display_path }
      local line_key = smart_labels[i] or ' '
      contents[line] = '   ' .. line_key .. '   ' .. display_filename .. display_path
      line = line + 1
    end

    -- Resize quick menu window if needed
    local win_cfg = vim.api.nvim_win_get_config(Buffer_manager_win_id)
    if win_cfg.height ~= desired_height then
      win_cfg.height = desired_height
      pcall(vim.api.nvim_win_set_config, Buffer_manager_win_id, win_cfg)
    end

    -- Update buffer contents
    vim.api.nvim_buf_set_option(Buffer_manager_bufh, 'modifiable', true)
    vim.api.nvim_buf_set_lines(Buffer_manager_bufh, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(Buffer_manager_bufh, 'modifiable', false)
    vim.cmd(string.format(':call cursor(%d, %d)', current_buf_line, 1))

    -- Refresh extmarks
    local ns_id = vim.api.nvim_create_namespace('BufferManagerIndicator')
    pcall(vim.api.nvim_buf_clear_namespace, Buffer_manager_bufh, ns_id, 0, -1)
    for i = 1, #valid_marks do
      local key = smart_labels[i] or ' '
      vim.api.nvim_buf_set_extmark(Buffer_manager_bufh, ns_id, i - 1, 0, {
        undo_restore = false,
        invalidate = true,
        conceal = '',
        virt_text = {
          { '  ', 'FloatNormal' },
          { ' ' .. key .. ' ', 'Search' },
          { '  ', 'FloatNormal' },
          { extmark_contents[i][1] or '', config.hl_filename or 'Bold' },
          { extmark_contents[i][2] or '', config.hl_path or 'Comment' },
        },
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
        cursorline_hl_group = 'CursorLine',
      })
    end

    -- Reapply keymaps
    set_menu_keybindings(smart_labels)
    -- Reapply horizontal movement restrictions respecting active labels
    local active_labels_set = {}
    if smart_labels then
      for _, lbl in pairs(smart_labels) do if lbl and lbl ~= ' ' then active_labels_set[lbl] = true end end
    else
      for _, lbl in ipairs(config.line_keys) do active_labels_set[lbl] = true end
    end
    apply_horizontal_restrictions(Buffer_manager_bufh, Buffer_manager_win_id, active_labels_set)
  end)
  _refreshing = false
end

return M
