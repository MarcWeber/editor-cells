if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells 

" VimL implementation of completion setting completefunc and allowing to use
" m-<n> to select <n>th entry fast

fun! cells#vim8#completions#Trait(cell) abort

  let a:cell.limit = get(a:cell, 'limit', 1000)
  let a:cell.goto_mappings = get(a:cell, 'goto_mappings', map(range(1,9)+["0"], "v:val"))

  let s:c.completion_cell = a:cell

  let a:cell.complete_ends = get(a:cell, 'complete_ends', ['<space>'])
  set omnifunc=cells#vim8#completions#CompletionFunction


  call cells#traits#Ask(a:cell)

  fun! a:cell.l_complete(event) abort
    let self.position = get(a:event, 'position', getpos('.'))
    let col_m1 = self.position[3]
    let line = getline('.')
    

    " ask cells identified by selector for completions and show popup
    let event = {}
    let event['type'] = 'completions'
    let event['line_split_at_cursor'] = [line[0: self.position[2]-1], line[self.position[2]:]]
    let event['position'] = self.position
    let event['limit'] = self.limit
    let event['match_types'] = ['prefix', 'ycm', 'camel_case_like']
    call self.cancel_ask({'type': 'completions', 'event': event, 'cb': 'completions_received', 'selector': get(a:event, 'selector', 'all')})
  endf

  " TODO: 
  fun! a:cell.completions_received(request) abort
    if self.position != getpos('.')
      echom 'aborting completion because cursor moved'
      return
    endif

    let all = cells#util#Flatten1(a:request.results_good)
    let context_default = filter(copy(all), 'get(v:val, "context", "default") == "default"')
    let context_other   = filter(copy(all), 'get(v:val, "context", "default") != "default"')
    let column = min(map(copy(all), 'v:val.column'))

    let completions = []

    for i in all
      let pref = a:request.event.line_split_at_cursor[0][column:i.column-1]
      if pref != ""
        for c in i.completions
          let c.word = pref. c.word
        endfor
      endif
      let completions += i.completions
    endfor
    call sort(completions, {a, b -> a.certainity - b.certainity > 0 ? 1 : -1})
    let s:c.current_completions = {'completions':  completions, 'column': column, 'pos': self.position}

    if len(self.goto_mappings) > 0
      call cells#Emit({'type': 'mappings_changed', 'sender': self.id})
      let nr = 1
      for x in self.goto_mappings
        if len(s:c.current_completions.completions) <= nr | break | endif
        let c = s:c.current_completions.completions[nr]
        let c['abbr'] = get(c, 'abbr', get(c, 'word')).' ['.self.goto_mappings[nr-1].']'
        let nr += 1
      endfor
    endif

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
    call cells#Emit({'type': 'mappings_changed', 'sender': self.id})

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
        echom 'returning culmn '.s:c.current_completions.column
        return s:c.current_completions.column-1
      else
        " vim sets col after returning .. ?
        call cells#Emit({'type': 'complete', 'position': getpos('.')})
        return 0
      endif
    else
      if s:c.have_completions
        echom 'base '.a:base

        call self.setup_mappings()
        return s:c.current_completions.completions
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
