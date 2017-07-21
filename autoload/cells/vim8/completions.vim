if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells 

" VimL implementation of completion setting completefunc and allowing to use
" m-<n> to select <n>th entry fast

fun! cells#vim8#completions#EventData(event)
  " expected event keys
  "  event['position'] = getpos('.')
  "  event['position'] = getpos('.')
  let event = a:event
  let col_m1 = event.position[3]
  let line   = getline('.')
  let event  = event
  let event['type'] = 'completions'
  let event['line_split_at_cursor'] = [line[0: event.position[2]-1], line[event.position[2]:]]
  return event
endf

fun! cells#vim8#completions#Compare(a, b)
  let asm = has_key(a:a, 'strong_match')
  let bsm = has_key(a:b, 'strong_match')

  return ((asm == bsm) ? (a:a.certainity - a:b.certainity > 0) : ( asm - bsm)) ? -1 : 1
endf

fun! cells#vim8#completions#Trait(cell) abort
  let a:cell.goto_mappings = get(a:cell, 'goto_mappings', map(range(1,9)+["0"], "v:val"))
  let s:c.completion_cell = a:cell

  let a:cell.complete_ends = get(a:cell, 'complete_ends', ['<space>', '<cr>'])
  set omnifunc=cells#vim8#completions#CompletionFunction


  call cells#traits#Ask(a:cell)

  fun! a:cell.l_complete(event) abort
    " ask cells identified by selector for completions and show popup
    let self.position = get(a:event, 'position', getpos('.'))
    let event = {'position': self.position, 'limit': a:event.limit, 'match_types' : a:event.match_types}
    let event = cells#vim8#completions#EventData(event)

    call self.cancel_ask('completions_received', {'type': 'completions', 'event': event})
  endf

  " TODO:
  fun! a:cell.completions_received(request) abort
    if self.position != getpos('.')
      echom 'aborting completion because cursor moved'
      return
    endif

    let all = cells#util#Flatten1(a:request.results_good)
    let column = min(map(copy(all), 'v:val.column'))

    let completions = {}

    for i in all
      let pref = a:request.event.event.line_split_at_cursor[0][column:i.column-1]
      if pref != ""
        for c in i.completions
          let c.word = pref. c.word
        endfor
      endif

      for c in i.completions
        if ! has_key(completions, c.word) || cells#vim8#completions#Compare(c, completions[c.word]) > 0
          let completions[c.word] = c
        endif
      endfor
    endfor

    " sorty by 1) strong_match 2) certainity

    let completions = sort(values(completions), 'cells#vim8#completions#Compare')

    let copmletions = completions[0:self.limit]

    let s:c.current_completions = {'completions':  completions, 'column': column, 'pos': self.position}

    if len(self.goto_mappings) > 0
      call g:cells.emit({'type': 'mappings_changed', 'sender': self.id})
      let nr = 0
      for x in self.goto_mappings
        if len(s:c.current_completions.completions) -1 < nr | break | endif
        let c = s:c.current_completions.completions[nr]
        let c['abbr'] = get(c, 'abbr', get(c, 'word')).' ['.self.goto_mappings[nr].']'
        let nr += 1
      endfor
    endif

    set cot=menu,menuone,noinsert,noselect
    call feedkeys("\<c-x>\<c-o>", 't')
  endf

  fun! a:cell.setup_mappings()
    " cannot return mappings, because Vim cannot call a function on rhs
    " when completing (it aborts completion)
    for lhs in  self.complete_ends
      exec 'inoremap <buffer> '.lhs.' <c-r>=g:cells.cells['. string(self.id) .'].clear_mappings()<cr>'.lhs
    endfor
    let nr = 1
    for lhs in self.goto_mappings
      exec 'inoremap <buffer> '.lhs. ' 'repeat("<c-n>", nr)
      let nr += 1
    endfor
  endf

  fun! a:cell.clear_mappings()
    call g:cells.emit({'type': 'mappings_changed', 'sender': self.id})

    for lhs in  self.complete_ends
      exec 'iunmap <buffer> '.lhs
    endfor

    for lhs in self.goto_mappings
      exec 'iunmap <buffer> '.lhs
      " could be smarter, thus restorting completions
    endfor
    return ""
  endf

  fun! a:cell.handle_completion(findstart, base) abort
    if a:findstart
      let s:c.have_completions = has_key(s:c, 'current_completions') &&  s:c.current_completions.pos == getpos('.')

      if s:c.have_completions
        return s:c.current_completions.column-1
      else
        " vim sets col after returning .. ?
        call g:cells.emit({'type': 'complete', 'position': getpos('.'), 'limit': self.limit, 'match_types' : ['prefix', 'ycm_like', 'camel_case_like', 'ignore_case', 'last_upper']})
        return 0
      endif
    else
      if s:c.have_completions
        call self.setup_mappings()
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

fun! cells#vim8#completions#CompletionFunction(findstart, base) abort
  return s:c.completion_cell.handle_completion(a:findstart, a:base)
endf
