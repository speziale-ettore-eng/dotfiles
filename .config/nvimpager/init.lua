vim.opt.termguicolors = true
vim.opt.background = "dark"

-- Load colorschems from `nvim` configuration directory.

local nvim_data = vim.fn.stdpath("data"):gsub("/nvimpager$", "/nvim")
local cache_dir = nvim_data .. "/base46/"
local pieces = { "defaults", "syntax", "treesitter" }

for _, name in ipairs(pieces) do
  local cache = cache_dir .. name
  if vim.fn.filereadable(cache) == 0 then
    vim.notify("nvimpager: no theme cache at " .. cache, vim.log.levels.WARN)
  else
    local ok, err = pcall(dofile, cache)
    if not ok then
      vim.notify("nvimpager: failed to load " .. cache .. ": " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end
