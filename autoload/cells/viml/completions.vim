if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells 

" VimL implementation of completion setting completefunc and allowing to use
" m-<n> to select <n>th entry fast

fun! cells#viml#completions#EventData(event)
  " expected event keys
  "  event['position'] = getpos('.')
  let event = a:event
  let event['type'] = 'completions'
  call cells#util#CursorContext(event)
  return event
endf

fun! cells#viml#completions#Compare(a, b)
  let asm = has_key(a:a, 'strong_match')
  let bsm = has_key(a:b, 'strong_match')
  return ((asm == bsm) ? (a:a.w - a:b.w > 0) : ( asm - bsm)) ? -1 : 1
endf

fun! cells#viml#completions#TraitAutoTrigger(cell) abort
  " automatically triggers completions after specific characters for given
  " filetypes using completions
  " Example: use MyFastCompletion cell for completing everything after [a-z] before cursor
  " let cell = MyFastCompletion
  " call cells#viml#Cell({'traits': ['cells#viml#completions#TraitAutoTrigger'], 'by_filetype':  {'filetype_pattern' : '.*', 'when_regex_matches_current_line': '[a-z]|',  'completing_cells': [cell.id] }})
 
  let a:cell.by_filetype = get(a:cell, 'by_filetype', [])

  let a:cell.limit = get(a:cell, 'limit', 10)
  let a:cell.trigger_wait_ms = get(a:cell, 'trigger_wait_ms', 70)

  let a:cell.last_pos = [0,0,0,0]

  fun! a:cell.trigger_completion()
    if pumvisible() | return | endif " TODO or check refreshing completion ..

    let p = getpos('.')
    if (p == self.last_pos) | return | endif " never run twice - prevent endless cpu burning
    let self.last_pos = p

    let line = getline('.')
    let cursor_line = line[0: p[2]-2].'|'. line[p[2]:]

    let cell_ids = []
    let bname = bufname('%')
    let active = filter(copy(self.by_filetype), 'cursor_line =~ v:val.when_regex_matches_current_line && bname =~ v:val.filepath_regex')
    let cell_ids = cells#util#Union(map(copy(active), 'v:val.completing_cells'))
    if len(active) == 0 || len(cell_ids) == 0 | return | endif
    let trigger_wait_ms = min(map(copy(active), 'get(v:val, "trigger_wait_ms", self.trigger_wait_ms)'))

    if index( cell_ids, 'all') >= 0
      let completing_cells_selector = 'all'
    else
      let completing_cells_selector = {'ids': cell_ids}
    end

    if has_key(self, 'timer')
      call timer_stop(self.timer)
    endif
    let self.completion_event = {'type': 'complete', 'position': getpos('.'), 'limit': self.limit, 'match_types' : ['prefix', 'ycm_like', 'camel_case_like', 'ignore_case', 'last_upper'], 'completing_cells_selector' : completing_cells_selector}
    let self.timer = timer_start(self.trigger_wait_ms, function(self.start_completion, [], self), {'repeat': 1})
  endf

  fun! a:cell.start_completion(timer)
    call timer_stop(a:timer)
    call g:cells.emit(self.completion_event)
  endf

  augroup start
    exec 'au CursorMovedI * call g:cells.cells['. string(a:cell.id) .'].trigger_completion()'
  augroup end

endf

fun! cells#viml#completions#Trait(cell) abort
  let a:cell.goto_mappings = get(a:cell, 'goto_mappings', map(range(1,9)+["0"], "v:val"))
  let s:c.completion_cell = a:cell

  let a:cell.complete_ends = get(a:cell, 'complete_ends', ['<space>', '<cr>'])
  set omnifunc=cells#viml#completions#CompletionFunction


  call cells#traits#Ask(a:cell)

  fun! a:cell.l_complete(event) abort
    " ask cells identified by selector for completions and show popup
    let self.position = get(a:event, 'position', getpos('.'))
    let event = {'position': self.position, 'limit': a:event.limit, 'match_types' : a:event.match_types}
    let event = cells#viml#completions#EventData(event)

    call writefile([json_encode({'type': 'completions', 'event': event, 'selector': get(a:event, 'completing_cells_selector', 'all')})], '/tmp/json' )
    call self.cancel_ask('completions_received', {'type': 'completions', 'event': event, 'selector': get(a:event, 'completing_cells_selector', 'all')})
  endf

  fun! a:cell.completions_received(request) abort
    if self.position != getpos('.')
      echom 'aborting completion because cursor moved'
      return
    endif

    let all = filter(cells#util#Flatten1(a:request.results_good), 'len(v:val.completions) > 0')
    let column = min(map(copy(all), 'v:val.column'))

    let completions = {}

    for i in all
      let l = a:request.event.event.line_split_at_cursor[0]
      let pref = l[column-1: i.column - len(l) - 3 ]
      if pref != ""
        for c in i.completions
          let c.abbrev = c.word
          let c.word = pref. c.word
        endfor
      endif

      for c in i.completions
        if !has_key(c, 'w') | let c.w = 1 | endif
        if ! has_key(completions, c.word) || cells#viml#completions#Compare(c, completions[c.word]) < 0
          let completions[c.word] = c
        endif
      endfor
    endfor

    " sorty by 1) strong_match 2) weight

    let g:completions = completions
    let completions = sort(values(completions), 'cells#viml#completions#Compare')
    let copmletions = completions[0:self.limit]

    for c in completions
      " post process items
      " let c.menu = get(c, 'menu', '').' '.get(c, 'kind', '')
    endfo

    let s:c.current_completions = {'completions':  completions, 'column': column, 'pos': self.position}

    if len(self.goto_mappings) > 0
      " call g:cells.emit({'type': 'mappings_changed', 'sender': self.id})
      let nr = 0
      for x in self.goto_mappings
        if len(s:c.current_completions.completions) -1 < nr | break | endif
        let c = s:c.current_completions.completions[nr]
        let c['abbr'] = get(c, 'abbr', get(c, 'word')).' ['.self.goto_mappings[nr].']'
        let nr += 1
      endfor
    endif

    let g:completions = s:c.current_completions

    if len(s:c.current_completions) == 0 | return | endif

    set completeopt=menu,menuone,noinsert,noselect,preview
    " try to be graceful - overwrite omnifunc temporarely
    let self.old_omnifunc = &omnifunc
    set omnifunc=cells#viml#completions#CompletionFunction
    call feedkeys("\<c-x>\<c-o>", 't')
  endf

  fun! a:cell.completion_start()
    call self.setup_mappings()
  endf

  fun! a:cell.completion_ended()
    call self.clear_mappings()
  endf

  fun! a:cell.setup_mappings()
    " cannot return mappings, because Vim cannot call a function on rhs
    " when completing (it aborts completion)
    " for lhs in  self.complete_ends
    "   exec 'inoremap <buffer> '.lhs.' <c-r>=g:cells.cells['. string(self.id) .'].clear_mappings()<cr>'.lhs
    " endfor
    let nr = 1
    for lhs in self.goto_mappings
      " race condition?
      exec 'silent! inoremap <buffer> '.lhs. ' 'repeat("<c-n>", nr)
      let nr += 1
    endfor

    call self.completend_end_unmap_detect_start()
  endf

  fun! a:cell.clear_mappings()
    " call g:cells.emit({'type': 'mappings_changed', 'sender': self.id})

    " for lhs in  self.complete_ends
    "   exec 'iunmap <buffer> '.lhs
    " endfor

    for lhs in self.goto_mappings
      exec 'silent! iunmap <buffer> '.lhs
      " could be smarter, thus restorting completions
    endfor
    return ""
  endf

  fun a:cell.completend_end_unmap_detect_start()
    " NeoVim? TODO
    call timer_start(10, function(self.completend_end_unmap_detect_start_timer, [], self) , {"repeat": -1})
  endf
  fun a:cell.completend_end_unmap_detect_start_timer(timer)
    if !pumvisible()
      call timer_stop(a:timer)
      call self.completion_ended()
    endif
  endf

  fun! a:cell.handle_completion(findstart, base) abort
    if a:findstart
      let s:c.have_completions = has_key(s:c, 'current_completions') " && s:c.current_completions.pos == getpos('.')

      if s:c.have_completions
        return s:c.current_completions.column-1
      else
        " vim sets col after returning .. ?
        call g:cells.emit({'type': 'complete', 'position': getpos('.'), 'limit': self.limit, 'match_types' : ['prefix', 'ycm_like', 'camel_case_like', 'ignore_case', 'last_upper']})
        return 0
      endif
    else
      if s:c.have_completions
        if self.old_omnifunc != 'cells#viml#completions#CompletionFunction'
          exec 'set omnifunc='. self.old_omnifunc
        endif
        call self.completion_start()
        let r = s:c.current_completions.completions
        call remove(s:c, 'current_completions')
        return r
      else
        return []
      endif
      call remove(s:c, 'have_completions')
    endif
  endf

  return a:cell

endf

fun! cells#viml#completions#CompletionFunction(findstart, base) abort
  return s:c.completion_cell.handle_completion(a:findstart, a:base)
endf
