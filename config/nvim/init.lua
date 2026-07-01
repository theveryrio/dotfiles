-- ~/.config/nvim/init.lua

local opt = vim.opt

-- Indentation: 4-space, tabs expanded to spaces
opt.tabstop = 4        -- number of spaces a <Tab> counts for
opt.softtabstop = 4    -- spaces inserted/removed when editing with <Tab>/<BS>
opt.shiftwidth = 4     -- spaces used for each step of (auto)indent
opt.expandtab = true   -- convert tabs to spaces
opt.autoindent = true  -- copy indent from the current line on new lines
opt.smartindent = true -- smarter auto-indent for C-like code

-- Line numbers
opt.number = true         -- absolute number on the current line
opt.relativenumber = true -- relative numbers on other lines

-- Search
opt.ignorecase = true -- case-insensitive search...
opt.smartcase = true  -- ...unless the query contains uppercase
opt.incsearch = true  -- show matches while typing
opt.hlsearch = true   -- highlight all matches

-- Editing convenience
opt.mouse = "a"                -- enable mouse in all modes
opt.clipboard = "unnamedplus"  -- use the system clipboard
opt.wrap = false               -- do not wrap long lines
opt.scrolloff = 8              -- keep 8 lines visible above/below the cursor
opt.sidescrolloff = 8          -- keep 8 columns visible left/right of the cursor
opt.cursorline = true          -- highlight the current line
opt.signcolumn = "yes"         -- always show the sign column (avoids text shift)
opt.termguicolors = true       -- enable 24-bit RGB colors

-- Persistent undo
-- vim.fn.stdpath("state") resolves per-platform (XDG-compliant).
local undodir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
  -- mkdir with "p" creates parent dirs; guarded so it runs only when missing
  vim.fn.mkdir(undodir, "p")
end
opt.undofile = true      -- persist undo history across sessions
opt.undodir = undodir

-- Files and performance
opt.swapfile = false  -- disable swap files
opt.backup = false    -- disable backup files
