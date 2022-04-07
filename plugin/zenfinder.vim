" [zenfinder]
" Depends on: <ripgrep>
" ==============================================================================
" use ripgrep for listing files by default
if !exists('g:zenfinder_command')
  let g:zenfinder_command = 'rg %s --files --color=never --glob ""' 
endif
if !exists('s:files')  | let s:files = []  | endif
if !exists('s:prompt') | let s:prompt = '' | endif

function! s:LoadFiles() abort
  let cwd = escape(getcwd(), "\\")
  let command = substitute(g:zenfinder_command, '%s', cwd, '')
  let s:files = systemlist(command)->map({ index, file -> substitute(file, cwd, '', '')[1:] })
endfunction

function! s:LoadBuffers() abort
  let filelist = getbufinfo({'buflisted': 1})->map({ index, buffer -> buffer.name})
  let s:files = filelist
endfunction

function! s:FindFiles(pattern) abort
  if a:pattern == '' | return copy(s:files) | endif

  return matchfuzzy(s:files, a:pattern)
endfunction

function! s:TriggerPromptChanged() abort
  let s:prompt = getline('.')[3:]
  let matched_files = s:FindFiles(s:prompt)
  " See `:help setloclist` for info about this mapping
  let s:formatted_files = map(matched_files, { index, file -> { 'filename': file, 'lnum': 1 } })

  call setloclist(s:location_window_id, s:formatted_files, 'r')
endfunction

function! s:ClosePrompt() abort
  let s:prompt = ''
  execute "setlocal laststatus=" . s:previous_status
  q!
  lclose
endfunction

function! s:RunPrompt() abort
  call s:ClosePrompt()
  silent ll
endfunction

function! s:PromptHandleBackspace() abort
  if len(s:prompt) > 0
    return "\<BS>"
  endif

  return "\<Esc>"
endfunction

function! s:RotateActive(clockwise) abort
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

  call setloclist(s:location_window_id, s:formatted_files, 'r')
endfunction

function! s:OpenPrompt(type) abort
  if a:type == 'buffers'
    call s:LoadBuffers()
  else
    call s:LoadFiles()
  endif

  if len(s:files) == 0
    echo ':Zenfinder => No entries.'
    return
  endif

  " location list cannot open when empty, so set it first
  lexpr []
  lopen
  let s:location_window_id = win_getid()
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
  call s:TriggerPromptChanged()
  startinsert!

  autocmd TextChangedI <buffer> :call s:TriggerPromptChanged()

  inoremap <buffer><silent> <Esc> <Esc>:call <SID>ClosePrompt()<CR>
  inoremap <buffer><silent> <CR> <Esc>:call <SID>RunPrompt()<CR>
  imap <expr><buffer><silent> <BS> <SID>PromptHandleBackspace()

  inoremap <buffer><silent> <C-j> <C-o>:call <SID>RotateActive(1)<CR>
  inoremap <buffer><silent> <C-k> <C-o>:call <SID>RotateActive(0)<CR>
  inoremap <buffer><silent> <C-n> <C-o>:call <SID>RotateActive(1)<CR>
  inoremap <buffer><silent> <C-p> <C-o>:call <SID>RotateActive(0)<CR>
  inoremap <buffer> : <C-o>:
endfunction

command! -bang Zenfinder call s:OpenPrompt(expand('<bang>') == '!' ? 'buffers' : 'files')
