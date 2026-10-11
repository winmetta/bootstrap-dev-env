" Win Metta shared vim config. bootstrap-dev-env.sh copies this to
" ~/.config/winmetta/.vimrc and adds a `source` line for it at the top of
" ~/.vimrc, so anything you write below that line in ~/.vimrc overrides it.

" A user vimrc turns off Vim's built-in defaults (backspace over everything,
" incremental search, status ruler, ...). Load them back first.
source $VIMRUNTIME/defaults.vim

syntax on
filetype plugin indent on

let mapleader = ","

" Visual mode: pressing * or # searches for the selected text (not just a word).
vnoremap <silent> * :<C-u>call VisualSelection()<CR>/<C-R>=@/<CR><CR>
vnoremap <silent> # :<C-u>call VisualSelection()<CR>?<C-R>=@/<CR><CR>

function! VisualSelection() range
    let l:saved_reg = @"
    execute "normal! vgvy"
    let @/ = substitute(escape(@", "\\/.*'$^~[]"), "\n$", "", "")
    let @" = l:saved_reg
endfunction

" :W saves a file you do not own by writing it through sudo.
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!

" Mouse off, so you can select and copy text in the terminal (iTerm, Terminal)
" the normal way. Vim's defaults turn the mouse on, which makes a drag move the
" cursor or select inside vim instead. To use the mouse in vim again, put
" `set mouse=a` in your own ~/.vimrc below the source line.
set mouse=

" Show line numbers.
set number

" Indent with 4 spaces. (smartindent is omitted: `filetype plugin indent on`
" already indents per language and smartindent only gets in its way.)
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
