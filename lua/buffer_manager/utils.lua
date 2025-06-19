local Path = require("plenary.path")

local M = {}

function M.project_key()
  return vim.loop.cwd()
end

function M.normalize_path(item)
  if string.find(item, ".*:///.*") ~= nil then
    return Path:new(item)
  end
  return Path:new(Path:new(item):absolute()):make_relative(M.project_key())
end

function M.get_file_name(file)
  return file:match("[^/\\]*$")
end

function M.get_short_file_name(config, file)
  -- Get normalized file path
  file = tostring(M.normalize_path(file))
  local filename = M.get_file_name(file)

  if config.show_depth then
    -- Remove leading slashes
    local dirs = file:gsub("^/+", "")

    -- If the path is empty or has no slashes (i.e., just the filename), return an empty string
    if dirs == "" or not dirs:find("/") then
      return filename, ""
    end

    -- Remove the last element (the filename, after the last "/")
    dirs = dirs:match("(.+)/[^/]+$") or dirs

    -- Use custom separators
    dirs = dirs:gsub("/", config.dir_separator_icon)

    -- Calculate the number of spaces needed
    local path_left_icon_len = #config.path_surrounding_icon[1]
    local path_right_icon_len = #config.path_surrounding_icon[2]
    local left_length = 7 -- length of right margin + extmarks + spaces
      + #filename -- length of the filename
    local len_for_path = config.width
      - left_length
      - path_left_icon_len
      - path_right_icon_len
      - 2 -- for the left margin
    if len_for_path < 0 then
      return filename:sub(1, len_for_path - 1) .. "…", ""
    end

    local n_spaces = len_for_path - (#dirs > 0 and #dirs or 0)

    -- Shorten the path if it exceeds the maximum length
    if n_spaces < 1 then
      dirs = "…" .. dirs:sub(-n_spaces + 3)
      n_spaces = 1
    end

    -- Include spaces
    return filename,
      string.rep(" ", n_spaces)
        .. config.path_surrounding_icon[1]
        .. dirs
        .. config.path_surrounding_icon[2]
  else
    return filename, ""
  end
end

function M.get_short_term_name(term_name)
  return term_name:gsub("://.*//", ":")
end

function M.absolute_path(item)
  return Path:new(item):absolute()
end

function M.is_white_space(str)
  return str:gsub("%s", "") == ""
end

function M.buffer_is_valid(buf_id, buf_name)
  return 1 == vim.fn.buflisted(buf_id) and buf_name ~= ""
end

-- tbl_deep_extend does not work the way you would think
local function merge_table_impl(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == "table" then
      if type(t1[k]) == "table" then
        merge_table_impl(t1[k], v)
      else
        t1[k] = v
      end
    else
      t1[k] = v
    end
  end
end

function M.merge_tables(...)
  local out = {}
  for i = 1, select("#", ...) do
    merge_table_impl(out, select(i, ...))
  end
  return out
end

function M.deep_copy(obj, seen)
  -- Handle non-tables and previously-seen tables.
  if type(obj) ~= "table" then
    return obj
  end
  if seen and seen[obj] then
    return seen[obj]
  end

  -- New table; mark it as seen and copy recursively.
  local s = seen or {}
  local res = {}
  s[obj] = res
  for k, v in pairs(obj) do
    res[M.deep_copy(k, s)] = M.deep_copy(v, s)
  end
  return setmetatable(res, getmetatable(obj))
end

function M.replace_char(string, index, new_char)
  return string:sub(1, index - 1) .. new_char .. string:sub(index + 1)
end

return M
