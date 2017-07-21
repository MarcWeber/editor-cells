" some exapmle implementation.
" cells#examples#TraitTestCompletion(cell) is usable actually

fun! cells#examples#TraitTestMappings(cell) abort
  fun! a:cell.l_mappings(event)
    let mappings = [
          \ {'scope': 'global',                 'mode': 'normal', 'lhs': '<f2>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f2 was hit'}},
          \ {'scope': 'bufnr:4',                'mode': 'normal', 'lhs': '<f3>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f3 was hit'}},
          \ {'scope': 'filename_regex:\.js$',   'mode': 'normal', 'lhs': '<f4>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f4 was hit'}},
          \ ]

    call self.reply_now(a:event, mappings)
  endf
  fun! a:cell.l_do_echo(event) abort
    echom a:event.text
  endf
  call g:cells.emit({'type': 'mappings_changed', 'sender': a:cell.id})
  return a:cell
endf

fun! cells#examples#TraitTestSigns(cell) abort
  fun! a:cell.l_signs(event) abort
    call self.reply_now(a:event, [{'bufnr': 1, 'name': 'test', 'category' : 'test', 'definition': 'text=-', 'signs': [{'line': 3, 'comment': 'comment about sign - on line 3' }]}])
  endf
  call g:cells.emit({'type': 'signs_changed', 'sender': a:cell.id})
  return a:cell
endf

fun! cells#examples#TraitTestQuickfix(cell) abort
  fun! a:cell.l_quickfix_list(event) abort
    call self.reply_now(a:event, {'truncated': v:false, 'list': [{'bufnr': 1, 'text': 'error', 'col': 10, 'lnum': 5, 'type' : 'E'}]})
  endf
  call g:cells.emit({'type': 'quickfix_list_available', 'sender': a:cell.id})
  return a:cell
endf

" {{{

fun! cells#examples#TraitTestCompletion(cell) abort

  call cells#traits#Ask(a:cell)

  fun! a:cell.l_completions(event)
    " sample implemenattion illustrating how word completion within a buffer
    " can be done showing words nearby the cursor rated higher
    " implementing multiple match_types.

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\S*$')

    let words = {}
    let linenr = 1

    let nearby_cursor_lines = 100

    for w in split(join(getline(1, line('.'))," "),'[/#$|,''"`; \&()[\t\]{}.,+*:]\+')
      if (w == word_before_cursor) | continue | endif
      let line_diff = linenr - a:event.event.position[1]
      if abs(line_diff) > 100
        let certainity = 1
      else
        " words in lines nearby cursor are more important ..
        let certainity = 1 + (1.0 - abs(line_diff) / nearby_cursor_lines)
        if linenr > a:event.event.position[1]
          " lines below cursor are less important than above cursor
          let certainity = sqrt(certainity)
        endif
      endif
      let words[w] = {'word': w, 'certainity': certainity}
      let linenr += 1
    endfor

    let completions = cells#util#match_by_type(values(words), word_before_cursor, a:event.event.match_types)
    call self.reply_now(a:event, [{
          \ 'column': a:event.event.position[2] - len(word_before_cursor),
          \ 'completions' : completions
    \ }])
  endf

  return a:cell

endf
" }}}
