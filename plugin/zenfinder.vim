" [zenfinder]
" Depends on: <ripgrep>, [cfilter] (built-in)
" ==============================================================================
if exists('g:zenfinder_loaded') | finish | endif
let g:zenfinder_loaded = 1

" use ripgrep for listing files by default
if !exists('g:zenfinder_command')
  let g:zenfinder_command = 'rg %s --files --color=never --glob ""' 
endif

" use ripgrep for listing files by default
if !exists('g:zenfinder_max_ll_files')
  let g:zenfinder_max_ll_files = 9
endif

" Add cfilter if it wasn't added already
packadd! cfilter

let s:files = []
let s:prompt = ''
let s:is_prompt_open = 0
let s:prompt_window_id = 0
let s:mode = 'fuzzy'

" VENDOR
" ==============================================================================
" taken from https://github.com/dsummersl/vus/blob/master/autoload/_.vim
function! s:Throttle(fn, wait, ...) abort
  let l:leading = 1
  if exists('a:1')
    let l:leading = a:1
  end

  let l:result = {
        \'data': {
        \'leading': l:leading,
        \'lastcall': 0,
        \'lastresult': 0,
        \'lastargs': 0,
        \'timer_id': 0,
        \'wait': a:wait},
        \'fn': a:fn
        \}

  function l:result.wrap_call_fn(...) dict
    let self.data.lastcall = reltime()
    let self.data.lastresult = call(self.fn, self.data.lastargs)
    let self.data.timer_id = 0
    return self.data.lastresult
  endfunction

  function l:result.lastresult() dict
    return self.data.lastresult
  endfunction

  function l:result.call(...) dict
    if self.data.leading
      let l:lastcall = self.data.lastcall 
      let l:elapsed = reltimefloat(reltime(l:lastcall)) 
      if type(l:lastcall) == 0 || l:elapsed > self.data.wait / 1000.0
        let self.data.lastargs = a:000
        return self.wrap_call_fn()
      endif
    elseif self.data.timer_id == 0
      let self.data.lastargs = a:000
      let self.data.timer_id = timer_start(self.data.wait, self.wrap_call_fn)
      return '<throttled>'
    else
      return '<throttled>'
    endif
    return self.data.lastresult
  endfunction
  return l:result
endfunction
" ==============================================================================

function s:EmptyLLAndWipeBuffers()
  let items = getloclist(s:location_window_id)
  for item in items
    let buffer = item.bufnr
    if !buflisted(buffer)
      execute 'bwipeout' buffer
    end
  endfor
endfunction

function! s:AliasCommand(from, to) abort
  exec 'cnoreabbrev <expr> '.a:from
        \ .' ((getcmdtype() is# ":" && getcmdline() is# "'.a:from.'")'
        \ .'? ("'.a:to.'") : ("'.a:from.'"))'
endfunction

function! s:LoadFiles() abort
  let cwd = escape(getcwd(), "\\")
  let command = substitute(g:zenfinder_command, '%s', cwd, '')
  let s:files = systemlist(command)->map({ index, file -> substitute(file, cwd, '', '')[1:] })
endfunction

function! s:LoadBuffers() abort
  let filelist = getbufinfo({'buflisted': 1})->map({ index, buffer -> buffer.name})
  let s:files = filelist
endfunction

function! s:ToggleRegexMode() abort
  if s:mode == 'regex'
    let s:mode = 'fuzzy'
  else
    let s:mode = 'regex'
  endif
  call s:TriggerPromptChanged()
endfunction

function! s:FindFiles(pattern) abort
  if a:pattern == '' | return copy(s:files) | endif

  if s:mode == 'regex'
    return filter(copy(s:files), { index, file -> file =~ a:pattern })
  endif

  return matchfuzzy(s:files, a:pattern)
endfunction

function! s:TriggerPromptChanged() abort
  let s:prompt = getline('.')[3:]
  let matched_files = s:FindFiles(s:prompt)[:g:zenfinder_max_ll_files]
  " See `:help setloclist` for info about this hash format
  let s:formatted_files = map(matched_files, { index, file -> { 'filename': file, 'lnum': 1 } })

  call s:SetLL(s:formatted_files)
endfunction
let s:ThrottledTriggerPromptChanged = s:Throttle(function('s:TriggerPromptChanged'), 50, 1)

function! s:FocusLL() abort
  call win_gotoid(s:location_window_id)
endfunction

function! s:FocusPrompt() abort
  call win_gotoid(s:prompt_window_id)
endfunction

function! s:CloseZenfinder() abort
  if s:is_prompt_open == 0 | return | endif
  let s:is_prompt_open = 0

  let s:prompt = ''
  call s:FocusPrompt()
  execute "setlocal laststatus=" . s:previous_status
  bwipeout
  call s:EmptyLLAndWipeBuffers()

  call s:FocusLL()
  lexpr []
  lclose
endfunction

function! s:RunPrompt() abort
  call s:FocusLL()
  .ll
  call s:CloseZenfinder()
endfunction

function! s:PromptHandleBackspace() abort
  if len(s:prompt) > 0
    return "\<BS>"
  endif

  return "\<Esc>"
endfunction

function! s:PromptHandleCW() abort
  if len(s:prompt) > 0
    return "\<C-w>"
  endif

  return ''
endfunction

function! s:SetLL(files) abort
  call setloclist(s:location_window_id, a:files, 'r')

  let currentmode = s:mode == 'regex' ? 'regex' : 'fuzzy'
  let title = '[Zenfinder] [' . currentmode . ']'
	call setloclist(s:location_window_id, [], 'a', { 'title' : title })
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

  call s:SetLL(s:formatted_files)
endfunction

function! s:Reject(pattern) abort
  if !s:is_prompt_open
    echo ":Zenfinder => Finder closed"
    return
  endif

  call s:FocusLL()
  execute "Lfilter! " . a:pattern
endfunction

function! s:Filter(pattern) abort
  if !s:is_prompt_open
    echo ":Zenfinder => Finder closed"
    return
  endif

  call s:FocusLL()
  execute "Lfilter " . a:pattern
endfunction

function! s:LLRemoveAtCursor()
  let linenum = line('.')
  let items = copy(s:formatted_files)
  let s:formatted_files = filter(items, { index -> (index + 1) != linenum })

  call s:SetLL(s:formatted_files)
endfunction

function! FormatLocationList(info)
  " not Zenfinder's location list
  if !exists('s:location_window_id') | return | endif

  let formatted_items = []
  let items = getloclist(s:location_window_id)
  for item in items
    let bufinfo = getbufinfo(item.bufnr)[0]
    let cwd = escape(getcwd(), "\\")
    let filename = substitute(bufinfo.name, cwd, '.', '')
    let filename = substitute(filename, '\\', '/', 'g')
    call add(formatted_items, filename)
  endfor

  return formatted_items
endfunction

function! s:OpenAllInSplit(vertical) abort
  let command = a:vertical == 1 ? 'vsp' : 'sp'
  let items = getloclist(s:location_window_id)
  for item in items
    let path = getbufinfo(item.bufnr)[0].name
    silent execute command . ' ' . path
  endfor

  call s:CloseZenfinder()
endfunction

function! s:OpenZenfinder(type) abort
  if s:is_prompt_open
    call s:CloseZenfinder()
    return
  endif
  let s:is_prompt_open = 1

  if a:type == 'buffers'
    call s:LoadBuffers()
  else
    call s:LoadFiles()
  endif

  if len(s:files) == 0
    let s:is_prompt_open = 0
    echo ':Zenfinder => No entries.'
    return
  endif

  " location list
  lexpr []
  botright lopen
  let s:location_window_id = win_getid()
  setlocal nonu
  setlocal nornu
  nnoremap <buffer><silent> <CR> :call <SID>RunPrompt()<CR>
  nnoremap <buffer><silent> <C-Tab> :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent> <BS> :call <SID>CloseZenfinder()<CR>
  nnoremap <buffer><silent> <Esc> :call <SID>CloseZenfinder()<CR>
  nnoremap <buffer><silent> q :call <SID>CloseZenfinder()<CR>
  nnoremap <buffer><silent> a :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent> A :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent> i :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent> I :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent> C :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent><nowait> c :call <SID>FocusPrompt()<CR>a
  nnoremap <buffer><silent> x :call <SID>LLRemoveAtCursor()<CR>
  nnoremap <buffer><silent> d :call <SID>LLRemoveAtCursor()<CR>

  " pseudo-prompt
  botright new
  let s:prompt_window_id = win_getid()
  let s:previous_status = &laststatus
  setlocal laststatus=0
  resize 1
  setlocal nonu
  setlocal nornu
  set buftype=nofile
  set bufhidden=hide
  setlocal noswapfile
  put ='>> '
  call s:ThrottledTriggerPromptChanged.call()
  startinsert!

  autocmd TextChangedI <buffer> :call s:ThrottledTriggerPromptChanged.call()

  inoremap <buffer><silent> <Esc> <Esc>:call <SID>CloseZenfinder()<CR>
  inoremap <buffer><silent> <CR> <Esc>:call <SID>RunPrompt()<CR>
  imap <expr><buffer><silent> <BS> <SID>PromptHandleBackspace()
  imap <expr><buffer><silent> <C-w> <SID>PromptHandleCW()
  inoremap <buffer><silent> <C-j> <C-o>:call <SID>RotateActive(1)<CR>
  inoremap <buffer><silent> <C-k> <C-o>:call <SID>RotateActive(0)<CR>
  inoremap <buffer><silent> <C-n> <C-o>:call <SID>RotateActive(1)<CR>
  inoremap <buffer><silent> <C-p> <C-o>:call <SID>RotateActive(0)<CR>
  inoremap <buffer><silent> <C-Tab> <Esc>:call <SID>FocusLL()<CR>
  inoremap <buffer> : <Esc>:call <SID>FocusLL()<CR>:
  inoremap <buffer> <C-r> <C-o>:call <SID>ToggleRegexMode()<CR>
endfunction

" configure the custom formatting function
set quickfixtextfunc=FormatLocationList

command! -bang Zenfinder call s:OpenZenfinder(expand('<bang>') == '!' ? 'buffers' : 'files')
command! -nargs=1 Zreject call s:Reject(<f-args>)
command! -nargs=1 Zfilter call s:Filter(<f-args>)
command! Zsplit call s:OpenAllInSplit(0)
command! Zvsplit call s:OpenAllInSplit(1)
call s:AliasCommand('ze', 'Zenfinder')
call s:AliasCommand('zr', 'Zreject')
call s:AliasCommand('zf', 'Zfilter')
call s:AliasCommand('zsp', 'Zsplit')
call s:AliasCommand('zvsp', 'Zvsplit')
