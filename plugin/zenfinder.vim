" [zenfinder]
" Depends on: <ripgrep>
" ==============================================================================
let g:zenfinder_command = 'rg %s --files --color=never --glob ""' " use ripgrep for listing files

if !exists('s:files')  | let s:files = []  | endif
if !exists('s:prompt') | let s:prompt = '' | endif

" Use `zenfinder_command` to find all files in the current directory, and
" store it in `s:files`.
function! LoadFiles() abort
  let cwd = escape(getcwd(), "\\")
  let command = substitute(g:zenfinder_command, '%s', cwd, '')
  let s:files = systemlist(command)->map({ index, file -> substitute(file, cwd, '', '')[1:] })
endfunction

function! FindFiles(pattern) abort
  if a:pattern == '' | return copy(s:files) | endif

  return matchfuzzy(s:files, a:pattern)
endfunction

function! HandlePromptChanged() abort
  let matched_files = FindFiles(s:prompt)
  " See `:help setqflist` for info about this mapping
  let s:formatted_files = map(matched_files, { index, file -> { 'filename': file, 'lnum': 1 } })

  call setqflist(s:formatted_files, 'r')
endfunction

function! TriggerPromptChanged() abort
  let s:prompt = getline('.')[3:]
  call HandlePromptChanged()
endfunction

function! ClosePrompt() abort
  let s:prompt = ''
  execute "setlocal laststatus=" . s:previous_status
  q!
  cclose
endfunction

function! RunPrompt() abort
  call ClosePrompt()
  silent cc
endfunction

function! PromptHandleBackspace() abort
  if len(s:prompt) > 0
    return "\<BS>"
  endif

  return "\<Esc>"
endfunction

function! RotateActive(clockwise) abort
  let items = copy(s:formatted_files)
  if a:clockwise == 1
    let head = items[0]
    let tail = items[1:]
    let s:formatted_files = extend(tail, [head])
  else
    let head = items[-1]
    let tail = items[:-2]
    let s:formatted_files = extend([head], tail)
  endif

  call setqflist(s:formatted_files, 'r')
endfunction

function! OpenPrompt() abort
  call LoadFiles()
  copen
  below new
  let s:previous_status = &laststatus
  setlocal laststatus=0
  resize 1
  setlocal nonu
  setlocal nornu
  set buftype=nofile
  set bufhidden=hide
  setlocal noswapfile
  put ='>> '
  call TriggerPromptChanged()
  startinsert!

  autocmd TextChangedI <buffer> :call TriggerPromptChanged()

  inoremap <buffer><silent> <Esc> <Esc>:call ClosePrompt()<CR>
  inoremap <buffer><silent> <CR> <Esc>:call RunPrompt()<CR>
  imap <expr><buffer><silent> <BS> PromptHandleBackspace()

  inoremap <buffer><silent> <C-j> <C-o>:call RotateActive(1)<CR>
  inoremap <buffer><silent> <C-k> <C-o>:call RotateActive(0)<CR>
  inoremap <buffer><silent> <C-n> <C-o>:call RotateActive(1)<CR>
  inoremap <buffer><silent> <C-p> <C-o>:call RotateActive(0)<CR>
  inoremap <buffer> : <C-o>:
endfunction

nnoremap <silent> <leader>q :call OpenPrompt()<CR>
