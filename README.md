# Zenfinder
A minimalistic, file-centric, **experimental** fuzzy finder for Vim, using the
location list.

See the [help file](doc/zenfinder.txt) for the complete documentation: `:help
zenfinder`.

# Installation

```vimscript
Plug 'gosukiwi/vim-zenfinder'
```

# Why
Most popular fuzzy finders for Vim have either too many external dependencies,
don't integrate very well with Vim's ecosystem, or are massive and packed with
unused features.

The location list is Vim's way of dealing with lists of files and their
positions. This finder focuses on on that interaction.

Usage goes as follows:

* Execute `:zf` or trigger a custom mapping in your config to open Zenfinder
* Type in the prompt to fuzzy find your file (you can toggle regex mode here
  if needed)
* Navigate down and up with `<C-j>` and `<C-k>`
* Once you see the file you want, you can press `ENTER` to open it

Advanced usage:

* If you want to operate on multiple files, you can use commands such as
  `:Zfilter` and `:Zreject` to filter files even further, or press `x` to
  delete the file under the cursor from the list
* You can open those files with `:Zsplit` and `:Zvsplit`, or even run commands
  on them with good old `:help :ldo`!

**Minimal:** Zenfinder is ~300 lines of Vimscript. It uses `ripgrep` for
blazing fast file listing (respecting things like `.gitignore`), as well as
Vim's built-in `matchfuzzy` function to quickly search the results.

**Fast:** Because it's so small, Zenfinder is really fast, and you can
configure it to make it even faster if you need to.

**No dependencies:** While it uses `ripgrep` by default, you can define your
own command to fetch all relevant files.

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
