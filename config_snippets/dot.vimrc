version 4.6

set kp=man
set modeline modelines=9
set sw=4 ts=4
set ignorecase smartcase infercase " Search defaultvalues :)
set incsearch " looks nice :)
set shm=rnft
set showcmd
set hlsearch
set pt=<F11>
let mapleader = ","

" enter digraphs with ^k
dig Eu 8364

" C-mode
autocmd BufNewFile,BufRead *.[Cch] set tw=0 ai si cin

" Perl-mode
autocmd BufNewFile,BufRead *.pl set tw=0 sw=4 sm cin cinkeys=0{,0},:,!^F,o,O,e cms=#%s

" Python-mode
autocmd BufNewFile,BufRead *.py set ts=4 sw=4 tw=0 et pm= cms=#%s

" Ansible
autocmd BufNewFile,BufRead *.yml set sw=2 tw=0 et ai cms=#%s

" git
au BufNewFile,BufRead *.gitconfig set tabstop=8 shiftwidth=8 expandtab patchmode=

" LaTeX
autocmd BufReadPre *.tex set showmatch mp=latex\ % ai tw=70 autowrite

" crontab
autocmd BufReadPre crontab.* set nowritebackup

" Sanity
autocmd BufReadPre */.* set commentstring=#%s
autocmd BufReadPre */Makefile set commentstring=#%s

" Macros
map ,m :w:make

map ' `
map Q gq

"Very common typo.
cabbr Wq! wq!
cabbr Wq wq

map ,e 1G}:r !date +"- \%Y/\%m/\%d \%R"o	

map ,ci mqo00"qy$dd`q
map ,cc mqo"qp00"qy$dd`q@q`qj

map ,l :set invlist|:set listchars=tab:>-,trail:$|

map ,d :set nowrap showcmd nosol ve=all cursorline cursorcolumn:hi CursorColumn ctermfg=red

map u :noh

" Append modeline after last line in buffer.
" Use substitute() instead of printf() to handle '%%s' modeline in LaTeX
" files.
function! AppendModeline()
  let l:modeline = printf(" vim\x3A set ts=%d sw=%d tw=%d %set pm=%s:",
        \ &tabstop, &shiftwidth, &textwidth, &expandtab ? '' : 'no',&patchmode)
  let l:modeline = substitute(&commentstring, "%s", l:modeline, "")
  call append(line("^")+1, l:modeline)
endfunction
nnoremap <silent> <Leader>s :call AppendModeline()<CR>

" Colors

"colorscheme sane

" get rid of that ugly pink
hi DiffChange term=bold ctermbg=2
hi DiffText   term=reverse cterm=bold ctermbg=3
" get parens to work
"hi MatchParen cterm=inverse ctermbg=white ctermfg=cyan
hi MatchParen cterm=bold ctermbg=white ctermfg=cyan
" or let loaded_matchparen=1

" clearer diff
hi DiffAdd        ctermbg=4 ctermfg=black
hi DiffChange     ctermbg=2 ctermfg=black
hi DiffDelete     ctermbg=6 ctermfg=blue
hi DiffText       ctermbg=3 ctermfg=black

" keep column when possible
"set nostartofline
set virtualedit=block

" do not assume comments continue on next line
set formatoptions-=ro
" remove comment leader on joining lines
set formatoptions+=j
" do not indent on #
set indentkeys-=0#
