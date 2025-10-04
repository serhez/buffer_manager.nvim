local M = {}

function M.get_file_name(file)
  return file:match("[^/\\]*$")
end

function M.buffer_is_valid(buf_id, buf_name)
  return vim.fn.buflisted(buf_id) == 1 and buf_name ~= ""
end

local function merge_table_impl(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(t1[k]) == "table" then
      merge_table_impl(t1[k], v)
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

return M
