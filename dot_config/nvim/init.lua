-- ~/.config/nvim/init.lua
---[[ gruvbox 颜色主题
-- 设置背景
vim.opt.background = 'dark'  -- 可以设置为 'light' 以使用亮色版本
-- 启用 gruvbox 主题
vim.cmd.colorscheme("gruvbox")
--]]

---[[ 基础设置
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.relativenumber = true
vim.opt.number = true
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
--]]

---[[ lazy.nvim 插件管理器配置

require("lazy").setup({
  -- 插件列表
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "neovim/nvim-lspconfig" },
  { "cdelledonne/vim-cmake" },
  { "yamatsum/nvim-cursorline" },
  { "jannis-baum/vivify.vim" },
  { "nvim-tree/nvim-tree.lua", version = "*", lazy = false, dependencies = { "nvim-tree/nvim-web-devicons", }, config = function() require("nvim-tree").setup {} end, },
  { "lervag/vimtex", ft = { "tex" }, config = function() vim.g.vimtex_view_method = "zathura" vim.g.vimtex_compiler_method = "latexmk" vim.g.vimtex_quickfix_mode = 0 end, },
  { "hrsh7th/nvim-cmp", dependencies = { "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-cmdline", "saadparwaiz1/cmp_luasnip", "kdheepak/cmp-latex-symbols", } },
  { "L3MON4D3/LuaSnip", dependencies = { "rafamadriz/friendly-snippets" }, }
})
--]]

---[[ treesitter 配置
require("nvim-treesitter.configs").setup({
  ensure_installed = {"c","cpp", "python","markdown","lua","bash", "json", "cmake","rust"},
  highlight = { enable = true },
  fold = { enable = true },
})
vim.opt.foldmethod = 'expr'  -- 使用表达式控制折叠
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'  -- Treesitter 提供的折叠表达式
vim.opt.foldenable = false
--]]

---[[ 启用 lspconfig 并配置
local lsputil = require("lspconfig.util")
-- 配置 clangd
local function find_compile_commands_dir(fname) -- 在根目录或者build目录下寻找 compile_commands.json
  if lspconfig.util.path.exists(lspconfig.util.path.join(fname, "build", "compile_commands.json")) then
    return lspconfig.util.path.join(fname, "build")
  elseif lspconfig.util.path.exists(lspconfig.util.path.join(fname, "compile_commands.json")) then
    return fname
  end
end
vim.lsp.config("clangd",{ -- 通过.clangd等文件寻找根目录并加载compile_commands.json
  filetypes = { "c", "cpp", "objc", "objcpp" },
  cmd = { "clangd" },
  on_attach = function(_, bufnr)
    local opts = { noremap=true, silent=true, buffer=bufnr }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.diagnostic.config({
      virtual_text = true,
      signs = true,
      underline = true,
      update_in_insert = false,
    })
  end,
  on_new_config = function(new_config, root_dir)
    local cc_dir = find_compile_commands_dir(root_dir)
    if cc_dir then
      new_config.cmd = { "clangd", "--compile-commands-dir=" .. cc_dir }
    end
  end,
  root_dir = lsputil.root_pattern(".clangd", ".project_root", "compile_commands.json", ".git")
})
vim.lsp.enable("clangd")
--]]

---[[ nvim-cursorline 配置
require("nvim-cursorline").setup {
  cursorline = { enable = true, timeout = 0, number = true, },
  cursorword = { enable = true, min_length = 3, hl = { underline = true }, }
}
--]]

---[[ 控制中文输入法自动切换
local current_input_method = ""

-- 函数来切换到指定的输入法
local function switch_input_method(method)
  os.execute("fcitx5-remote -s " .. method) -- 切换到指定输入法
end

-- 进入插入模式时切换到之前使用的输入法
vim.api.nvim_create_autocmd("InsertEnter", {
  pattern = "*",
  callback = function()
    if current_input_method ~= "" then
      switch_input_method(current_input_method)
    end
  end,
})

-- 离开插入模式时记录当前输入法
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    current_input_method = vim.fn.system("fcitx5-remote -n"):gsub("%s+", "") -- 获取当前输入法并去掉空格
    os.execute("fcitx5-remote -c") -- 切换到英文输入法
  end,
})
--]]

