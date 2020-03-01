# any-jump

**— IDE madness without overhead for 40+ languages**

_Nvim plugin for "jump to defitinition⚒" and "find usages🔬" feature through nice popup ui_

_nvim 0.4+ with popup windows required; vim support is planned for near releases_

Based on syntax rules for 40 languages and **fast regexp engines** like ripgrep and ag. Required `rg` or `ag` to be installed. GNU grep support dropped for flavor of blazing perfomance (can be implemented in future releases).

- jump to symbol/class/const/variable definition with `<leader>j`
- display and jump to symbol/class/const/variable usages inside current project

![screenshot](/main.gif)

_Jumping through source code of Discource app_

## Installation

via vim-plug:

```viml
Plug 'pechorin/any-jump.nvim'
```

## Keybindings

Default global mappings for normal mode:

```viml
" Jump to definition under cursore
nnoremap <leader>j :AnyJump<CR>

" open previous opened file (after jump)
nnoremap <leader>ab :AnyJumpBack<CR>

" open last closed search window again
nnoremap <leader>al :AnyJumpLastResults<CR>
```

To **disable default keybindings* write:

```viml
let g:any_jump_disable_default_keybindings = v:true
```

Mappings for popup search window

```viml
au FileType any-jump nnoremap <buffer> o :call g:AnyJumpHandleOpen()<cr>
au FileType any-jump nnoremap <buffer><CR> :call g:AnyJumpHandleOpen()<cr>
au FileType any-jump nnoremap <buffer> p :call g:AnyJumpHandlePreview()<cr>
au FileType any-jump nnoremap <buffer> <tab> :call g:AnyJumpHandlePreview()<cr>
au FileType any-jump nnoremap <buffer> q :call g:AnyJumpHandleClose()<cr>
au FileType any-jump nnoremap <buffer> <esc> :call g:AnyJumpHandleClose()<cr>
au FileType any-jump nnoremap <buffer> u :call g:AnyJumpHandleUsages()<cr>
au FileType any-jump nnoremap <buffer> U :call g:AnyJumpHandleUsages()<cr>
au FileType any-jump nnoremap <buffer> b :call g:AnyJumpToFirstLink()<cr>
au FileType any-jump nnoremap <buffer> T :call g:AnyJumpToggleGrouping()<cr>
au FileType any-jump nnoremap <buffer> a :call g:AnyJumpToggleAllResults()<cr>
au FileType any-jump nnoremap <buffer> A :call g:AnyJumpToggleAllResults()<cr>
```

## Settings

```viml
" Show line numbers in search rusults
let g:any_jump_list_numbers = v:true

" Auto search usages
let g:any_jump_usages_enabled = v:false

" Auto group results by filename
let g:any_jump_grouping_enabled = v:false

" Amount of preview lines for each search result
let g:any_jump_preview_lines_count = 5

" Max search results, other results can be opened via [a]
let g:any_jump_max_search_results = 7

" Prefered search engine: rg or ag
let g:any_jump_search_prefered_engine = 'rg'
" Ungrouped results ui variants:
" - 'filename_first'
" - 'filename_last'

let g:any_jump_results_ui_style = 'filename_first' "


" Any-jump window size & position options
let g:any_jump_window_width_ratio  = 0.6
let g:any_jump_window_height_ratio = 0.6
let g:any_jump_window_top_offset   = 4
```

## Features

### open definitions and usages list

![screenshot](/usages.png)

### preview definition with `p` or `tab`

![screenshot](/preview.png)

### group results by file

![screenshot](/group_by_file.png)

### search results without line numbers and different ui style

![screenshot](/no_ln.png)

## Supported languages

- ruby
- elixir
- crystal
- rust
- haskell
- java
- javascript
- typescript
- scala
- kotlin
- php
- protobuf
- scss
- fsharp
- c++
- coffeescript
- go
- lua
- nim
- scad
- elisp
- nix
- clojure
- coq
- systemverilog
- objc
- racket
- vhdl
- scheme
- r
- sql
- faust
- vala
- matlab
- python
- pascal
- tex
- swift
- shell
- perl
- csharp
- commonlisp
- ocaml
- erlang
- julia
- sml
- groovy
- dart
- fortran

## Original idea

Comes from dumb-jump.el emacs package

## Issues and contibutions

Please open issue on any question and problem
