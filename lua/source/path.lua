local M = {}
local vim = vim
local loop = vim.loop
local api = vim.api

M.items = {}
M.callback = false

-- onDirScanned handler for vim.loop
local function onDirScanned(_, data)
  if data then
    local function iter()
      return vim.loop.fs_scandir_next(data)
    end
    for name, type in iter do
        table.insert(M.items, {type = type, name=name})
    end
  end
  M.callback = true
end

local fileTypesMap = setmetatable({
    ['file'] = "(file)",
    ['directory'] = "(dir)",
    ['char'] = "(char)",
    ['link'] = "(link)",
    ['block'] = "(block)",
    ['fifo'] = "(pipe)",
    ['socket'] = "(socket)"
}, {__index = function()
    return '(unknown)'
  end
})

M.getCompletionItems = function(prefix, score_func)
  local complete_items = {}
  for _, val in ipairs(M.items) do
    local score = score_func(prefix, val.name)
    if score < #prefix/3 or #prefix == 0 then
      table.insert(complete_items, {
        word = val.name,
        kind = 'Path ' .. fileTypesMap[val.type],
        score = score,
        icase = 1,
        dup = 1,
        empty = 1,
      })
    end
  end
  return complete_items
end

M.getCallback = function()
  return M.callback
end

M.triggerFunction = function()
  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  local keyword = line_to_cursor:match("[^%s\"].*")
  if keyword ~= '/' then
    -- TODO rewrite this
    local index = string.find(keyword:reverse(), '/') or 1
    local length = string.len(keyword) - index + 1
    keyword = string.sub(keyword, 1, length)
    -- keyword = keyword:match("%s*(%S+)%w*/.*$")
  end

  local path = vim.fn.expand('%:p:h')
  if keyword ~= nil then
    local expanded_keyword = vim.fn.glob(keyword)
    local home = vim.fn.expand("$HOME")
    if expanded_keyword:sub(1, 1) == '/' or string.find(expanded_keyword, home) ~= nil then
      path = expanded_keyword
    else
      path = vim.fn.expand('%:p:h')
      path = path..'/'..keyword
    end
  end

  M.items = {}
  loop.fs_scandir(path, onDirScanned)
end

return M
