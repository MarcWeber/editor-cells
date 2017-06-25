fun! cells#tests#TestVimLEvent() abort
  " SIMPLE TEST: create cells, emit event, wait for reply, check replies, kill cells
  let cell1 = cells#viml#Cell({})
  fun! cell1.l_reply1(event)
    call self.reply_result(a:event, 1)
  endf

  let cell2 = cells#viml#Cell({})
  fun! cell2.l_reply1(event)
    call self.reply_result(a:event, 2)
  endf

  let cell3 = cells#viml#Cell({})
  fun! cell3.l_reply1(event)
    call self.reply_result(a:event, 3)
  endf

  let celle = cells#viml#Cell({})
  fun! celle.l_reply1(event)
    call self.reply_error(a:event, 'manual error')
  endf

  " emit test event and wait for results
  let cell_c = cells#viml#CellReplyCollector({})
  fun! cell_c.killed()
    let g:results = self.results
  endf

  call cells#Emit({'type': 'reply1', 'reply_to': cell_c.id})
  let results = map(filter(copy(g:results), 'has_key(v:val, "result")'), 'v:val.result')
  let errors  = map(filter(copy(g:results), 'has_key(v:val, "error")' ), 'v:val.error')
  if results != [1,2,3] | throw "results 1,2,3 expeted" | endif
  if len(errors) != 1 | throw "one error expected" | endif

  call cell1.kill()
  call cell2.kill()
  call cell3.kill()
  call celle.kill()
  unlet g:results
endf

fun! cells#tests#TraitTestMappings(cell) abort
  fun! a:cell.l_mappings(event)
    let mappings = [
          \ {'scope': 'global',                 'mode': 'normal', 'lhs': '<f2>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f2 was hit'}},
          \ {'scope': 'bufnr:4',                'mode': 'normal', 'lhs': '<f3>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f3 was hit'}},
          \ {'scope': 'filename_regex:\.js$',   'mode': 'normal', 'lhs': '<f4>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f4 was hit'}},
          \ ]

    call self.reply_result(a:event, mappings)
  endf
  fun! a:cell.l_do_echo(event) abort
    echom a:event.text
  endf
  call cells#Emit({'type': 'mappings_changed', 'sender': a:cell.id})
  return a:cell
endf

fun! cells#tests#TraitTestSigns(cell) abort
  fun! a:cell.l_signs(event) abort
    call self.reply_result(a:event, [{'bufnr': 1, 'name': 'test', 'category' : 'test', 'definition': 'text=-', 'signs': [{'line': 3, 'comment': 'comment about sign - on line 3' }]}])
  endf
  call cells#Emit({'type': 'signs_changed', 'sender': a:cell.id})
  return a:cell
endf

fun! cells#tests#TraitTestQuickfix(cell) abort
  fun! a:cell.l_quickfix_list(event) abort
    call self.reply_result(a:event, {'truncated': v:false, 'list': [{'bufnr': 1, 'text': 'error', 'col': 10, 'lnum': 5, 'type' : 'E'}]})
  endf
  call cells#Emit({'type': 'quickfix_list_available', 'sender': a:cell.id})
  return a:cell
endf

" {{{

fun! cells#tests#TraitTestCompletion(cell) abort

  call cells#traits#Ask(a:cell)

  fun! a:cell.l_completions(event)
    " sample implemenattion illustrating how word completion within a buffer
    " can be done showing words nearby the cursor rated higher
    " implementing multiple match_types.

    let word_before_cursor = matchstr(a:event.line_split_at_cursor[0], '\zs\S*$')

    let words = {}
    let linenr = 1

    for w in split(join(getline(1, line('.'))," "),'[/#$|,''"`; \&()[\t\]{}.,+*:]\+')
      if (w == word_before_cursor) | continue | endif
      let line_diff = linenr - a:event.position[1]
      if line_diff > 100
        let certainity = 1
      else
        " words in lines nearby cursor are more important ..
        let certainity = 1 + abs(100.0 - line_diff) / 500
        if linenr > a:event.position[1]
          " lines below cursor are less important than above cursor
          let certainity = sqrt(certainity)
        endif
      endif
      let words[w] = {'word': w, 'certainity': certainity}
      let linenr += 1
    endfor

    let completions = cells#util#match_by_type(values(words), word_before_cursor, a:event.match_types)
    call self.reply_result(a:event, [{
          \ 'column': a:event.position[2] - len(word_before_cursor),
          \ 'completions' : completions
    \ }])
  endf

  return a:cell

endf
" }}}
