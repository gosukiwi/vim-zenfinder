# Zenfinder
A minimalistic, file-centric fuzzy finder for Vim, using the location list.

The location list was made to be a list of file positions. This finder will
allow you to fuzzy find your files, and populate the location list with the
results. You can then use regular Vim commands to manipulate the location
list, mostly `:ldo`.

For example, you could run a replace across several files:

```
.md # select all markdown files
:   # enter command line mode
:ldo %s/replace this/with this/g
```

## Minimal
Zenfinder is ~100 lines of Vimscript. It uses `ripgrep` for blazing fast file
listing (respecting things like `.gitignore`), as well as Vim's built-in
`matchfuzzy` function to quickly search the results.

## No dependencies
While it uses `ripgrep` by default, you can define your own command to fetch
all relevant files.

```
" by default, use ripgrep
let g:zenfinder_command = 'rg %s --files --color=never --glob ""'

" use ag, the silver searcher
let g:zenfinder_command = 'ag %s -l --nocolor -g ""'

" macOS/Linux
let g:zenfinder_command = 'find %s -type f'

" Windows
let g:zenfinder_command = 'dir %s /-n /b /s /a-d'
```

# Installation

```vimscript
" optional, this is the default value
let g:zenfinder_command = 'rg %s --files --color=never --glob ""'

" the example assumes <leader> is mapped to something useful, like spacebar
nnoremap <silent> <leader>f :Zenfinder<CR>
nnoremap <silent> <leader>b :Zenfinder!<CR>
```

# Usage
Trigger with your mapping, or just using `:Zenfinder files` or
`:Zenfinder buffers`.

Navigate your files by typing, to fuzzy find and filter the search, choose the
current file with `<C-j>` and `<C-k>` (`<C-n>` and `<C-p>` are also
available), `:` to enter command line mode, `ENTER` to navigate into the file.
