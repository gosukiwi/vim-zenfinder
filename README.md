# Zenfinder
A minimalistic, file-centric, **experimental** fuzzy finder for Vim, using the
location list.

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

See the [doc/zenfinder.txt](help) file for the complete documentation! `:help
zenfinder`.

## Minimal
Zenfinder is ~200 lines of Vimscript. It uses `ripgrep` for blazing fast file
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
Plug 'gosukiwi/vim-zenfinder'
```
