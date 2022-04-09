# Zenfinder
A minimalistic, file-centric, **experimental** fuzzy finder for Vim, using the
location list.

See the [help file](doc/zenfinder.txt) for the complete documentation: `:help
zenfinder`.

# Installation

```vimscript
Plug 'gosukiwi/vim-zenfinder'

" ...

" recommended mappings, you can use anything here
nnoremap <silent> <leader>f :Zenfinder<CR>
nnoremap <silent> <leader>b :Zenfinder!<CR>
```

# Usage
Regular usage is as simple as:

* Execute `:ze` or trigger a custom mapping in your config to open Zenfinder
* Type in the prompt to fuzzy find your file (you can toggle regex mode with
  `<C-r>` if needed)
* Navigate down and up with `<C-j>` and `<C-k>`
* Once you see the file you want, you can press `ENTER` to open it

From time to time, you might need to operate on several files. With Zenfinder,
you can:

* Filter files with `:Zfilter` and `:Zreject`
* Press `x` or `d` to delete the file under the cursor from the list
* Run commands on them with `:ldo` (ex: replace a string in all matched files)
* Open those files with `:Zsplit` and `:Zvsplit`

# Why
Most popular fuzzy finders for Vim have either too many external dependencies,
don't integrate very well with Vim's ecosystem, or are massive and packed with
unused features.

The location list is Vim's way of dealing with lists of files and their
positions. This finder focuses on on that interaction.

## Minimal
Zenfinder is ~400 lines of Vimscript. It uses `ripgrep` for blazing fast file
listing (respecting things like `.gitignore`), as well as Vim's built-in
`matchfuzzy` function to quickly search the results.

## Fast
Because it's so small, Zenfinder is really fast, and you can configure it to
make it even faster if you need to.

## No dependencies
While it uses `ripgrep` by default, you can define your own command to fetch
all relevant files. Ex:

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
