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
let s:match_mode = 'fuzzy'

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
  let s:find_mode = 'files'
  let cwd = escape(getcwd(), "\\")
  let command = substitute(g:zenfinder_command, '%s', cwd, '')
  let s:files = systemlist(command)->map({ index, file -> substitute(file, cwd, '', '')[1:] })
endfunction

function! s:LoadBuffers() abort
  let s:find_mode = 'buffers'
  let s:buffers = getbufinfo({ 'buflisted': 1 })
        \ ->filter({ index, buffer -> fnamemodify(getbufinfo(buffer.bufnr)[0].name, ':p:h') != getbufinfo(buffer.bufnr)[0].name[:-2] })
        \ ->map({ index, buffer -> buffer.bufnr })
endfunction

function! s:ToggleRegexMode() abort
  if s:match_mode == 'regex'
    let s:match_mode = 'fuzzy'
  else
    let s:match_mode = 'regex'
  endif
  call s:TriggerPromptChanged()
endfunction

function! s:FindFiles(pattern) abort
  if a:pattern == '' | return copy(s:files) | endif

  if s:match_mode == 'regex'
    return filter(copy(s:files), { index, file -> file =~ a:pattern })
  endif

  return matchfuzzy(s:files, a:pattern)
endfunction

function! s:FindBuffers(pattern) abort
  if a:pattern == '' | return copy(s:buffers) | endif

  let buffers = map(copy(s:buffers), "{ 'bufnr': v:val, 'file': fnamemodify(getbufinfo(v:val)[0].name, ':.') }")
  if s:match_mode == 'regex'
    let result = filter(buffers, { index, bufninfo -> bufninfo.file =~ a:pattern })
  else
    let result = matchfuzzy(buffers, a:pattern, { 'key': 'file' })
  endif

  return map(result, 'v:val.bufnr')
endfunction

function! s:TriggerPromptChanged() abort
  let s:prompt = getline('.')[3:]
  if s:find_mode == 'files'
    let matched_files = s:FindFiles(s:prompt)[:g:zenfinder_max_ll_files]
    " See `:help setloclist` for info about this hash format
    let s:formatted_files = map(matched_files, { index, file -> { 'filename': file, 'lnum': 1 } })
    call s:SetLL(s:formatted_files)
  else " match buffers
    let matched_buffers = s:FindBuffers(s:prompt)[:g:zenfinder_max_ll_files]
    " See `:help setloclist` for info about this hash format
    let s:formatted_buffers = map(matched_buffers, { index, bufnr -> { 'bufnr': bufnr, 'lnum': 1 } })
    call s:SetLL(s:formatted_buffers)
  endif
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

  let currentmode = s:match_mode == 'regex' ? 'regex' : 'fuzzy'
  let title = '[Zenfinder] [' . currentmode . '] [' . getcwd() . ']'
	call setloclist(s:location_window_id, [], 'a', { 'title' : title })
endfunction

function! s:RotateActive(clockwise) abort
  if s:find_mode == 'files'
    let items = copy(s:formatted_files)
  else
    let items = copy(s:formatted_buffers)
  endif

  if a:clockwise == 1
    let head = items[0]
    let tail = items[1:]
    let newlist = extend(tail, [head])
  else
    let head = items[-1]
    let tail = items[:-2]
    let newlist = extend([head], tail)
  endif

  if s:find_mode == 'files'
    let s:formatted_files = newlist
  else
    let s:formatted_buffers = newlist
  endif

  call s:SetLL(newlist)
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
  
  if s:find_mode == 'files'
    let items = copy(s:formatted_files)
    let s:formatted_files = filter(items, { index -> (index + 1) != linenum })
    call s:SetLL(s:formatted_files)
  else
    let items = copy(s:formatted_buffers)
    let s:formatted_buffers = filter(items, { index -> (index + 1) != linenum })
    call s:SetLL(s:formatted_buffers)
  endif
endfunction

function! FormatLocationList(info)
  " not Zenfinder's location list
  if !exists('s:location_window_id') | return | endif

  let formatted_items = []
  let items = getloclist(s:location_window_id)
  for item in items
    let bufinfo = getbufinfo(item.bufnr)[0]
    let filename = fnamemodify(bufinfo.name, ':.')
    let filename = substitute(filename, '\\', '/', 'g')
    if filename == ''
      let filename = '[No Name ' . bufinfo.bufnr . ']'
    endif
    call add(formatted_items, filename)
  endfor

  return formatted_items
endfunction

function! s:OpenAllInSplit(vertical) abort
  if !s:is_prompt_open
    echo ":Zenfinder => Finder closed"
    return
  endif

  let command = a:vertical == 1 ? 'vsp' : 'sp'
  let items = getloclist(s:location_window_id)
  if a:firstline == a:lastline
    let fromindex = 0
    let toindex = len(items)
  else
    let fromindex = a:firstline - 1
    let toindex = a:lastline - 1
  endif

  let index = 0
  for item in items
    if index >= fromindex && index <= toindex
      let path = getbufinfo(item.bufnr)[0].name
      silent execute command . ' ' . path
    endif
    let index += 1
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

  if (s:find_mode == 'files' && len(s:files) == 0) || (s:find_mode == 'buffers' && len(s:buffers) == 0)
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
  nnoremap <buffer><silent> <C-a> :Zsplit<CR>
  nnoremap <buffer><silent> <C-v> :Zvsplit<CR>
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
  setlocal winfixheight
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
  inoremap <buffer><silent> <C-a> <C-o>:Zsplit<CR>
  inoremap <buffer><silent> <C-v> <C-o>:Zvsplit<CR>
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
command! -range Zsplit <line1>,<line2>call s:OpenAllInSplit(0)
command! -range Zvsplit <line1>,<line2>call s:OpenAllInSplit(1)
call s:AliasCommand('ze', 'Zenfinder')
call s:AliasCommand('zr', 'Zreject')
call s:AliasCommand('zf', 'Zfilter')
call s:AliasCommand('zsp', 'Zsplit')
call s:AliasCommand('zvsp', 'Zvsplit')
