" some exapmle implementation.

fun! cells#examples#TraitTestMappings(cell) abort
  fun! a:cell.l_mappings(event)
    let mappings = [
          \ {'scope': 'global',                 'mode': 'normal', 'lhs': '<f2>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f2 was hit'}},
          \ {'scope': 'bufnr:4',                'mode': 'normal', 'lhs': '<f3>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f3 was hit'}},
          \ {'scope': 'filepath_regex:\.js$',   'mode': 'normal', 'lhs': '<f4>', 'emit_event': {'type': 'do_echo', 'text': 'scope=g f4 was hit'}},
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


fun! cells#examples#TraitCompletionLastInsertedTexts(cell) abort " {{{

  call cells#traits#Ask(a:cell)

  let a:cell.last_inserted_texts = ['']
  let a:cell.last_pos = getpos('.')

  call a:cell.add_trait('cells#examples#TraitTestCompletionHelper')

  augroup TraitCompletionLastInsertedTexts
  au!
  exec 'au TextChanged,TextChangedI * call g:cells.cells['. string(a:cell.id) .'].__text_changed()'
  augroup end

  fun! a:cell.__text_changed()
    " if @. = self.last_inserted_texts[0] | return |endif
    " debug call insert(self.last_inserted_texts, @.)
    if self.last_pos[0:1] == getpos('.')[0:1]
      " same line
      let self.last_inserted_texts[0] = getline('.')
    else
      " new line
      call insert(self.last_inserted_texts, getline('.'))
    endif
    let self.last_inserted_texts = self.last_inserted_texts[0:100]
    let self.last_pos = getpos('.')
  endf

  fun! a:cell.l_completions(event)

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\S*$')
    let words = {}
    let linenr = 1

    let linenr = a:event.event.position[1]
    let contexts1 = [ 'last_edited_text' ]
    let contexts2 = [ 'last_edited_text_line' ]

    let certainity = 1.3
    for x in self.last_inserted_texts

      " words from last inserted texts
      for w in self.__line_to_items(x)
        let words[w] = {'word': w, 'w': certainity, 'contexts': contexts1, 'kind' : 'last inserted word'}
      endfor

      " lines from last inserted texts
      for line in split(x, "\n")
        let line = matchstr(line, '^\s*\zs.*')
        let words[line] = {'word': line, 'w': certainity, 'contexts': contexts2, 'kind': 'last inserted line'}
      endfor

      let certainity = certainity * 0.7
    endfor

    let completions = cells#util#match_by_type(values(words), word_before_cursor, a:event.event.match_types)
    call self.reply_now(a:event, [{
          \ 'column': a:event.event.position[2] - len(word_before_cursor),
          \ 'completions' : completions
    \ }])
  endf

  return a:cell

endf " }}}



fun! cells#examples#TraitCompletionLocalVars(cell) abort
  " very fuzzy searching of important vars nearby the cursor which you're very
  " likely to be using ..
  " TODO: rewrite using Python ?

  call cells#traits#Ask(a:cell)

  fun! a:cell.__post_function_vim(words, match, w)
    if a:match[1] != ''
      let a:words[a:match[1]] = {'word': a:match[1], 'w': a:w -0.1, 'contexts': ['local_var_like'], 'kind': 'LocalVars'}
    endif
    for x in split(a:match[2], ',\s*')
      let a:words[x] = {'word': x, 'replacement': 'a:'.x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'LocalVars'}
    endfor
  endf

  fun! a:cell.__post_function_fun_args(words, match, w)
      if a:match[1] != ''
        let a:words[a:match[1]] = {'word': a:match[1], 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'LocalVars'}
      endif
      for x in split(a:match[2], ',\s*')
        let a:words[x] = {'word': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'LocalVars' }
      endfor
  endf

  fun! a:cell.__first_match(words, match, w)
      if a:match[1] != ''
        let a:words[a:match[1]] = {'word': a:match[1], 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'LocalVars'}
      endif
  endf

  fun! a:cell.local_vars(linenr)

    let words = {}
    let linenr = 1
    let lines_max = 500

    let nearby_cursor_lines = 100

    let linenr = a:linenr
    let min = linenr - lines_max
    if min < 0 | let min = 1 | endif

    let regexes_by_filepath = [
        \ ['\%(\.js\)$'       , 'var\s\(\S\+\)\s', self.__first_match],
        \ ['\%(\.js\|\.vim\)$', 'function\%(\s\+\(\S\+\)\)\?(\([^)]*\))', self.__post_function_fun_args],
        \ ['\%(\.vim\)$', 'fun\S*!\?\%(\s\+\(\S\+\)\)\?(\([^)]*\))', self.__post_function_vim],
        \ ['\%(\.vim\)$'      , 'let\s\(\S\+\)\s', self.__first_match],
        \ ['\%(\.vim\)$'      , 'for\s\+\(\S\+\)', self.__first_match]
        \ ]

    let ext = bufname('%:t')
    let bname = bufname('%')

    let break_on_regex_by_ext = {
          \ 'js' : '^function',
          \ 'vim' : '^fun'
          \ }
    let break_on_regex = get(break_on_regex_by_ext, ext, '')

    let regexes_by_filepath = filter(copy(regexes_by_filepath), 'bname =~ v:val[0]')
    let words = {}

    while linenr >= min
      let line = getline(linenr)
      let w = 10.0 - ( abs(1.0 + a:linenr - linenr) / lines_max)
      if (break_on_regex != '' && line =~  break_on_regex) || linenr < min | break | endif

      for l in regexes_by_filepath
        let match = matchlist(line, l[1])
        if len(match) == 0 | continue | endif
        " call helper function to turn matches into words
        call call(l[2], [words, match, w], self)
      endfor
      let linenr -= 1
    endwhile
    return words
  endf

  fun! a:cell.l_completions(event)

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\w*$')

    let words = self.local_vars(a:event.event.position[1])

    let completions = cells#util#match_by_type(values(words), word_before_cursor, a:event.event.match_types)
    for c in completions
      if has_key(c, 'replacement') | let c.word = c.replacement | call remove(c, 'replacement') | endif
    endfor

    call self.reply_now(a:event, [{
          \ 'column': a:event.event.position[2] - len(word_before_cursor),
          \ 'completions' : completions
    \ }])
  endf

  return a:cell

endf

fun! cells#examples#TraitTestCompletionHelper(cell) abort
  fun! a:cell.__line_to_items(line)
    return  split(a:line,'[/#$|,''"`; \&()[\t\]{}.,+*:]\+')
  endfun
endf

fun! cells#examples#TraitTestCompletionThisBuffer(cell) abort
  " provides completions based on all buffers weightening recent buffers more

  call cells#traits#Ask(a:cell)

  call a:cell.add_trait('cells#examples#TraitTestCompletionHelper')

  fun! a:cell.l_completions(event)
    " sample implemenattion illustrating how word completion within a buffer
    " can be done showing words nearby the cursor rated higher
    " implementing multiple match_types.

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\S*$')

    let words = {}
    let linenr = 1

    let nearby_cursor_lines = 100

    for w in self.__line_to_items(join(getline(1, line('.'))," "))
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
      let words[w] = {'word': w, 'w': certainity}
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

fun! cells#examples#TraitTestCompletionAllBuffers(cell) abort

  call cells#traits#Ask(a:cell)

  call a:cell.add_trait('cells#examples#TraitTestCompletionHelper')

  let a:cell.buf_ids_entered_recently = []

  fun! a:cell.l_buf_enter(event)
    let self.buf_ids_entered_recently = [a:event.bufid]+filter(self.buf_ids_entered_recently, 'v:val != a:event.bufid')
  endf

  fun! a:cell.l_completions(event)

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\S*$')

    let words = {}
    let linenr = 1

    for bufnr in range(1, bufnr('$'))
      let recently_visited_care = 20
      let add  = (recently_visited_care - index(self.buf_ids_entered_recently[0:recently_visited_care], bufnr)) / recently_visited_care
      let contexts = [ 'rec_buf'.add ]
      for w in self.__line_to_items(join(getbufline(bufnr, 1, '$')," "))
        if (w == word_before_cursor) | continue | endif
        let words[w] = {'word': w, 'w': 0.5, 'contexts': contexts}
        let linenr += 1
      endfor
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

fun! cells#examples#CompletionsFromCompletionFunction(event, f)
  let findstart = 1
  let r1 = call(a:f, [1, ''])
  if r1 < 0 | continue | endif " no completion or cancel silently
  let base = a:event.event.line_split_at_cursor[0][r1:]
  let r2 = call(a:f, [0, base] )
  return { 'column': r1 +1, 'completions' : r2 }
endf

fun! cells#examples#TraitCompletionFromCompletionFunction(cell) abort
  " Usage:
  " call cells#viml#Cell({'traits': ['cells#examples#TraitCompletionFromCompletionFunction'], 'omnifuns': 'pythoncomplete#Complete' })

  fun! a:cell.l_completions(event)
    let completions = []
    for f in self.omnifuns
      call add(completions, cells#examples#CompletionsFromCompletionFunction(a:event, f))
    endfor
    " let completions = cells#util#match_by_type(values(words), word_before_cursor, a:event.event.match_types)
    call self.reply_now(a:event, completions)
  endf

  return a:cell
endf


fun! cells#examples#TraitDefinitionsAndUsages(cell) abort
  " Usage:
  " " goto definition of thing at cursor
  " nnoremap gd :call g:cells.cells['DefinitionsAndUsages'].definitions()<cr>
  " " goto usages of thing at cursor
  " nnoremap gu :call g:cells.cells['DefinitionsAndUsages'].usages()<cr>

  call cells#traits#Ask(a:cell)

  fun! a:cell.definitions()
    call self.ask('goto_or_quickfix', cells#util#CursorContext({'type': 'definitions', 'position': getpos('.')}))
  endf

  fun! a:cell.usages()
    call self.ask('goto_or_quickfix', cells#util#CursorContext({'type': 'usages', 'position': getpos('.')}))
  endf

  fun! a:cell.goto_or_quickfix(request)
    let flattened = cells#util#Flatten1(a:request.results_good)
    if len( flattened ) == 0
      echom "No hits"
    elseif len( flattened ) == 1
      call cells#util#GotoLocationKeys(flattened[0])
    else
      call setqflist(map(copy(flattened), '{"filename": v:val.filepath, "col": get(v:val,"column",1), "lnum": v:val.line, "text": get(v:val, "title", "")}'))
      cope
    endif
  endf

  return a:cell

endf
