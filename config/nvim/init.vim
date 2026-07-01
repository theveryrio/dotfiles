" ~/.config/nvim/init.vim

" Indentation: 4-space, tabs expanded to spaces
set tabstop=4        " number of spaces a <Tab> counts for
set softtabstop=4    " spaces inserted/removed when editing with <Tab>/<BS>
set shiftwidth=4     " spaces used for each step of (auto)indent
set expandtab        " convert tabs to spaces
set autoindent       " copy indent from the current line on new lines
set smartindent      " smarter auto-indent for C-like code

" Line numbers
set number           " absolute number on the current line
set relativenumber   " relative numbers on other lines

" Search
set ignorecase       " case-insensitive search...
set smartcase        " ...unless the query contains uppercase
set incsearch        " show matches while typing
set hlsearch         " highlight all matches

" Editing convenience
set mouse=a                " enable mouse in all modes
set clipboard=unnamedplus  " use the system clipboard
set nowrap                 " do not wrap long lines
set scrolloff=8            " keep 8 lines visible above/below the cursor
set sidescrolloff=8        " keep 8 columns visible left/right of the cursor
set cursorline             " highlight the current line
set signcolumn=yes         " always show the sign column (avoids text shift)
set termguicolors          " enable 24-bit RGB colors

" Persistent undo
" stdpath('state') resolves per-platform (XDG-compliant).
let s:undodir = stdpath('state') . '/undo'
if !isdirectory(s:undodir)
  call mkdir(s:undodir, 'p')
endif
let &undodir = s:undodir
set undofile               " persist undo history across sessions

" Files and performance
set noswapfile             " disable swap files
set nobackup               " disable backup files
