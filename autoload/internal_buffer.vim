" ----------------------------------------------
" Internal buffer prototype definition
" ----------------------------------------------
" represents ui internal structure

" abstract structure of internal buffer representation:
"
" buffer = [ array of lines ]
"
" line = [ list of items
"   { type, strat_col, finish_col, text, hl_group },
"   { ... },
"   ...
" ]

let s:nvim = has('nvim')

let s:InternalBuffer = {}

let s:InternalBuffer.MethodsList = [
      \'RenderLine',
      \'AddLine',
      \'AddLineAt',
      \'CreateItem',
      \'len',
      \'GetItemByPos',
      \'GetItemLineNumber',
      \'GetFirstItemOfType',
      \'TryFindOriginalLinkFromPos',
      \'TryRestoreCursorForItem',
      \'RenderUiUsagesList',
      \'RenderUi',
      \'StartUiTransaction',
      \'EndUiTransaction',
      \'GrepResultToItems',
      \'GrepResultToGroupedItems',
      \'RemoveGarbagedLines',
      \'JumpToFirstOfType',
      \'ClearBuffer',
      \]

" Produce new Render Buffer
fu! s:InternalBuffer.New() abort
  let object = {
        \"items":                    [],
        \"gc":                       v:false,
        \"preview_opened":           v:false,
        \"usages_opened":            v:false,
        \"grouping_enabled":         v:false,
        \"overmaxed_results_hidden": v:true,
        \"definitions_grep_results": [],
        \"usages_grep_results":      [],
        \"vim_bufnr":                0,
        \"popup_winid":              0,
        \"previous_bufnr":           0,
        \}

  for method in self.MethodsList
    let object[method] = s:InternalBuffer[method]
  endfor

  return object
endfu

fu! s:InternalBuffer.len() dict abort
  return len(self.items)
endfu

fu! s:InternalBuffer.RenderLine(items, line) dict abort
  let text           = s:nvim ? " " : ""
  let idx            = 0
  let next_start_col = 1

  " calculate & assign items start & end columns
  for item in a:items
    " separate items in line with 1 space
    if idx == 0
      let text = text . item.text
    else
      let text = text  . ' ' . item.text
      let next_start_col = next_start_col + 1
    endif

    let item.start_col = next_start_col
    let item.end_col   = next_start_col + len(item.text)

    let next_start_col  = item.end_col
    let idx            += 1
    " echo "r -> " . item.hl_group . ' l:' . a:line
    "       \ . ' ' . item.start_col . ':' . item.end_col
    "       \ . ' — ' . string(item.text)
  endfor

  " write final text to buffer
  call appendbufline(self.vim_bufnr, a:line - 1, text)

  " colorize
  for item in a:items
    if s:nvim
      call nvim_buf_add_highlight(
            \self.vim_bufnr,
            \-1,
            \item.hl_group,
            \a:line - 1,
            \item.start_col - 1,
            \item.end_col)
    else
      call prop_add(a:line, item.start_col, {
            \'length': item.len,
            \'type': item.hl_group,
            \'bufnr': self.vim_bufnr})
    endif
  endfor
endfu

fu! s:InternalBuffer.AddLine(items) dict abort
  if type(a:items) == v:t_list
    call self.RenderLine(a:items, self.len() + 1)
    call add(self.items, a:items)

    return v:true
  else
    echoe "array required, got invalid type: " . string(a:items)

    return v:false
  endif
endfu

fu! s:InternalBuffer.AddLineAt(items, line_number) dict abort
  if type(a:items) == v:t_list
    call self.RenderLine(a:items, a:line_number)
    call insert(self.items, a:items, a:line_number - 1)

    return v:true
  else
    echoe "array required, got invalid type: " . string(a:items)

    return v:false
  endif
endfu

" type:
"   'text' / 'link' / 'button' / 'preview_text'
fu! s:InternalBuffer.CreateItem(type, text, hl_group, ...) dict abort
  let data = {}

  if a:0
    let data = a:1
  endif

  let item = {
        \"type":      a:type,
        \"text":      a:text,
        \"len":       len(a:text),
        \"start_col": 0,
        \"end_col":   0,
        \"hl_group":  a:hl_group,
        \"gc":        v:false,
        \"data":      data
        \}

  " TODO: optimize this part for rednering perfomance
  if !s:nvim
    if prop_type_get(item.hl_group, {'bufnr': self.vim_bufnr}) == {}
      call prop_type_add(item.hl_group, {
            \'highlight': item.hl_group,
            \'bufnr': self.vim_bufnr
            \})
    endif
  endif

  return item
endfu


fu! s:InternalBuffer.GetItemByPos() dict abort
  if s:nvim
    let idx = getbufinfo(self.vim_bufnr)[0]['lnum']
  else
    " vim popup buffer doesn't have current line info inside getbufinfo()
    " so extract line nr from win
    let l:popup_pos = 0
    call win_execute(self.popup_winid, 'let l:popup_pos = getcurpos()')
    let idx = l:popup_pos[1]
  end

  if idx > len(self.items)
    return 0
  endif

  if s:nvim
    let column = col('.')
  else
    let column = 1
  end

  let line = self.items[idx - 1]

  for item in line
    if item.start_col <= column && (item.end_col >= column || item.end_col == -1 )
      return item
    endif
  endfor

  return 0
endfu

" not optimal, but ok for current ui with around ~100/200 lines
" COMPLEXITY: O(1)
fu! s:InternalBuffer.GetItemLineNumber(item) dict abort
  let i = 1

  for line in self.items
    for item in line
      if item == a:item
        return i
      endif
    endfor

    let i += 1
  endfor

  return 0
endfu

fu! s:InternalBuffer.GetFirstItemOfType(type, ...) dict abort
  let result = 0
  let layer  = 0

  if a:0 == 1
    let layer = a:1
  endif

  for line in self.items
    if type(result) == v:t_dict
      break
    endif

    for item in line
      let type_is_ok  = item.type == a:type
      let layer_is_ok = v:true

      if type(layer) == v:t_string
        let layer_is_ok = item.data.layer == layer
      endif

      if type_is_ok && layer_is_ok
        let result = item
        break
      endif
    endfor
  endfor

  return result
endfu

fu! s:InternalBuffer.TryFindOriginalLinkFromPos() dict abort
  let cursor_item = self.GetItemByPos()

  " try to find original link
  if type(cursor_item) == v:t_dict && type(cursor_item.data) == v:t_dict
        \ && cursor_item.type == 'link'
        \ && !has_key(cursor_item, 'original_link')
    let ln   = self.GetItemLineNumber(cursor_item)
    let line = self.items[ln - 1]

    for item in line
      if type(item.data) == v:t_dict && has_key(item.data, 'original_link')
        let cursor_item = item
        break
      endif
    endfor
  endif

  return cursor_item
endfu

fu! s:InternalBuffer.TryRestoreCursorForItem(item) dict abort
  if type(a:item) == v:t_dict
        \ && a:item.type == "link"
        \ && type(a:item.data) == v:t_dict
        \ && !has_key(a:item.data, 'group_header')

    let new_ln = self.GetItemLineNumber(a:item)

    " item removed
    if new_ln == 0
      call self.JumpToFirstOfType('link')
    else
      call cursor(new_ln, 2)
    endif
  else
    call self.JumpToFirstOfType('link')
  endif
endfu

fu! s:InternalBuffer.JumpToFirstOfType(type, ...) dict abort
  let item = self.GetFirstItemOfType(a:type, a:000)

  if type(item) == v:t_dict
    let ln = self.GetItemLineNumber(item)
    call cursor(ln, 2)
  endif
endfu

fu! s:InternalBuffer.ClearBuffer(buf) dict abort
  call deletebufline(a:buf, 1, self.len() + 1)
endfu

fu! s:InternalBuffer.StartUiTransaction(buf) dict abort
  if !s:nvim
    return
  endif

  call setbufvar(a:buf, '&modifiable', 1)
endfu

fu! s:InternalBuffer.EndUiTransaction(buf) dict abort
  if !s:nvim
    return
  endif

  call setbufvar(a:buf, '&modifiable', 0)
endfu

fu! s:InternalBuffer.GrepResultToItems(gr, current_idx, layer) dict abort
  let gr    = a:gr
  let items = []

  let options =
        \{ "path": gr.path, "line_number": gr.line_number, "layer": a:layer }
  let original_link_options =
        \{ "path": gr.path, "line_number": gr.line_number,
        \"layer": a:layer, "original_link": v:true }

  if g:any_jump_list_numbers
    let prefix_text = a:current_idx + 1
    let prefix = self.CreateItem("link", prefix_text, "Comment", options)

    call add(items, prefix)
  endif

  if g:any_jump_results_ui_style == 'filename_first'
    let path_text    = '' .  gr.path .  ":" . gr.line_number
    let matched_text = self.CreateItem("link", gr.text, "Statement", original_link_options)
    let file_path    = self.CreateItem("link", path_text, "String", options)

    call add(items, matched_text)
    call add(items, file_path)

  elseif g:any_jump_results_ui_style == 'filename_last'
    let path_text    = gr.path .  ":" . gr.line_number
    let matched_text = self.CreateItem("link", "" . gr.text, "Statement", original_link_options)
    let file_path    = self.CreateItem("link", path_text, "String", options)

    call add(items, file_path)
    call add(items, matched_text)
  endif

  return items
endfu

fu! s:InternalBuffer.GrepResultToGroupedItems(gr, current_idx, layer) dict abort
  let gr      = a:gr
  let items   = []

  let options =
        \{ "path": gr.path, "line_number": gr.line_number, "layer": a:layer }
  let original_link_options =
        \{ "path": gr.path, "line_number": gr.line_number,
        \"layer": a:layer, "original_link": v:true }

  if g:any_jump_list_numbers
    let prefix_text = a:current_idx + 1
    let prefix = self.CreateItem("link", prefix_text, "Comment", options)

    call add(items, prefix)
  endif

  let matched_text = self.CreateItem("link", gr.text, "Statement", original_link_options)

  call add(items, matched_text)

  return items
endfu

fu! s:InternalBuffer.RenderUiUsagesList(grep_results, start_ln) dict abort
  let start_ln     = a:start_ln
  let hidden_count = 0

  " TODO: move to method
  if type(g:any_jump_max_search_results) == v:t_number
        \ && g:any_jump_max_search_results > 0
        \ && self.overmaxed_results_hidden == v:true
    let collection = self.usages_grep_results[0 : g:any_jump_max_search_results - 1]
    let hidden_count = len(self.usages_grep_results[g:any_jump_max_search_results : -1])
  else
    let collection = self.usages_grep_results
  endif

  call self.AddLineAt([
    \self.CreateItem("text", ">", "Function", {'layer': 'usages'}),
    \self.CreateItem("text", self.keyword, "Identifier", {'layer': 'usages'}),
    \self.CreateItem("text", "usages", "Function", {'layer': 'usages'}),
    \], start_ln)


  let start_ln += 1

  call self.AddLineAt([ self.CreateItem("text", "", "Comment", {"layer": "usages"}) ], start_ln)

  let start_ln += 1

  let idx = 0
  if self.grouping_enabled
    " group by file name rendering
    let render_map = {}

    for gr in collection
      if !has_key(render_map, gr.path)
        let render_map[gr.path] = []
      endif

      call add(render_map[gr.path], gr)
    endfor

    let path_idx = 0
    for path in keys(render_map)
      let first_gr = render_map[path][0]
      let opts     = {
            \"path":         path,
            \"line_number":  first_gr.line_number,
            \"layer":        "definitions",
            \"group_header": v:true,
            \}

      let prefix     = self.CreateItem("link", ">", "Comment", opts)
      let group_name = self.CreateItem("link", path,  "Function", opts)
      let line       = [ prefix, group_name ]

      call self.AddLineAt(line, start_ln)
      let start_ln += 1

      for gr in render_map[path]
        let items = self.GrepResultToGroupedItems(gr, idx, "definitions")
        call self.AddLineAt(items, start_ln)

        let start_ln += 1
        let idx += 1
      endfor

      if path_idx != len(keys(render_map)) - 1
        call self.AddLineAt([ self.CreateItem("text", "", "Comment", {"layer": "usages"}) ], start_ln)

        let start_ln += 1
      endif

      let path_idx += 1
    endfor
  else
    for gr in collection
      let items = self.GrepResultToItems(gr, idx, "usages")
      call self.AddLineAt(items, start_ln)

      let idx += 1
      let start_ln += 1
    endfor
  endif

  if hidden_count > 0
    call self.AddLineAt([ self.CreateItem("text", "", "Comment", {"layer": "usages"}) ], start_ln)
    let start_ln += 1

    call self.AddLineAt([ self.CreateItem("more_button", '[ + ' . hidden_count . ' more ]', "Function", {"layer": "usages"}) ], start_ln)
    let start_ln += 1
  endif

  call self.AddLineAt([ self.CreateItem("text", " ", "Comment", {"layer": "usages"}) ], start_ln)

  return v:true
endfu

fu! s:InternalBuffer.RenderUi() dict abort
  " clear items before render
  let self.items = []

  call self.AddLine([ self.CreateItem("text", "", "Comment") ])

  call self.AddLine([
    \self.CreateItem("text", ">", "Function"),
    \self.CreateItem("text", self.keyword, "Identifier"),
    \self.CreateItem("text", "definitions", "Function"),
    \])

  call self.AddLine([ self.CreateItem("text", "", "Comment") ])

  " draw grep results
  let idx          = 0
  let hidden_count = 0

  " TODO: move to method
  if type(g:any_jump_max_search_results) == v:t_number
        \ && g:any_jump_max_search_results > 0
        \ && self.overmaxed_results_hidden == v:true
    let collection   = self.definitions_grep_results[0 : g:any_jump_max_search_results - 1]
    let hidden_count = len(self.definitions_grep_results[g:any_jump_max_search_results : -1])
  else
    let collection = self.definitions_grep_results
  endif

  if self.grouping_enabled
    " group by file name rendering
    let render_map = {}

    for gr in collection
      if !has_key(render_map, gr.path)
        let render_map[gr.path] = []
      endif

      call add(render_map[gr.path], gr)
    endfor

    let path_idx = 0

    for path in keys(render_map)
      let first_gr = render_map[path][0]
      let opts     = {
            \"path":         path,
            \"line_number":  first_gr.line_number,
            \"layer":        "definitions",
            \"group_header": v:true,
            \}

      let prefix     = self.CreateItem("link", ">", "Comment", opts)
      let group_name = self.CreateItem("link", path, "Function", opts)
      let line       = [ prefix, group_name ]

      call self.AddLine(line)

      for gr in render_map[path]
        let items = self.GrepResultToGroupedItems(gr, idx, "definitions")
        call self.AddLine(items)

        let idx += 1
      endfor

      if path_idx != len(keys(render_map)) - 1
         call self.AddLine([ self.CreateItem("text", "", "Comment") ])
      endif

      let path_idx += 1
    endfor
  else
    if len(collection)
      for gr in collection
        let items = self.GrepResultToItems(gr, idx, "definitions")
        call self.AddLine(items)

        let idx += 1
      endfor
    else
      call self.AddLine([ self.CreateItem("text", "No definitions results", "Comment") ])
    endif

    call self.AddLine([ self.CreateItem("text", "", "Comment") ])
  endif

  if hidden_count > 0
    call self.AddLine([ self.CreateItem("more_button", '[ + ' . hidden_count . ' more ]', "Function") ])
    call self.AddLine([ self.CreateItem("text", "", "Comment") ])
  endif

  if self.usages_opened && len(self.usages_grep_results) > 0
    call self.RenderUiUsagesList(self.usages_grep_results, self.len() + 1)
  endif

  call self.AddLine([ self.CreateItem("help_link", "> Help", "Function") ])

  call self.AddLine([ self.CreateItem("help_text", "", "Comment") ])
  call self.AddLine([ self.CreateItem("help_text", "[enter/o] open file   [tab/p] preview file   [esc/q] close ", "Comment") ])
  call self.AddLine([ self.CreateItem("help_text", "[T] toggle grouping   [a] show all results   [b] back to first result in list", "Comment") ])
  call self.AddLine([ self.CreateItem("help_text", "[u] show usages", "Comment") ])
endfu

fu! s:InternalBuffer.RemoveGarbagedLines() dict abort
  " remove marked for garbage collection lines
  let new_items = []

  for line in self.items
    if has_key(line[0], 'gc') == v:false || line[0].gc == v:false
      call add(new_items, line)
    endif
  endfor

  let self.items = new_items
endfu

" Public api
fu! internal_buffer#GetClass() abort
  return s:InternalBuffer
endfu
