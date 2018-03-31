" some exapmle implementation.
if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells

fun! cells#examples#TestCompletionManyColumns(cell) abort
  " for testing various start columns when completing
  let a:cell['completion-functions'] = get(a:cell, 'completion-functions', [])
  fun! a:cell.l_completions(event)
    let results = []
    let left = a:event.event.line_split_at_cursor[0]
    let l = len(left)
    for col in range(1, l)
      call add(results, {
        \ 'column': col,
        \ 'completions' : [{'word': left[col-1:].col , 'w': 0.5, 'kind': 'dummy'}]
      \ })
    endfor
    call self.reply_now(a:event, results )
  endf
  return a:cell
endf

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
        if w == word_before_cursor | continue | endif " do not offer the word before cursor
        let words[w] = {'word': w, 'w': certainity, 'contexts': contexts1, 'kind' : 'last inserted word'}
      endfor

      " lines from last inserted texts
      for line in split(x, "\n")
        let line = matchstr(line, '^\s*\zs.*')
        let words[line] = {'word': line, 'w': certainity, 'contexts': contexts2, 'kind': 'last inserted line'}
      endfor

      let certainity = certainity * 0.7
    endfor

    let completions = cells#util#match_by_type2(values(words), word_before_cursor)
    call self.reply_now(a:event, [{
          \ 'column': a:event.event.position[2] - len(word_before_cursor),
          \ 'completions' : completions
    \ }])
  endf

  return a:cell

endf " }}}

fun! cells#examples#TraitCompletionContext(cell) abort
  " very fuzzy searching of important vars nearby the cursor which you're very
  " likely to be using ..
  " TODO: rewrite using Python ?
  " TODO: refactor: split by language to make it much nicer

  call cells#traits#Ask(a:cell)

  fun! a:cell.__post_function_vim(words, match, w, line)
    if a:match[1] != ''
      call add( a:words,  {'word': a:match[1], 'w': a:w -0.1, 'contexts': ['local_var_like'], 'kind': 'Contexts A '.a:line})
    endif
    for x in split(a:match[2], ',\s*')
      call add( a:words,  {'word': x, 'replacement': 'a:'.x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts'})
    endfor
  endf

  fun! a:cell.__post_function_fun_args(words, match, w, line)
      if a:match[1] != ''
        call add( a:words,  {'word': a:match[1], 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts B'.a:line})
      endif
      for x in split(a:match[2], ',\s*')
        call add( a:words,  {'word': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts C'.a:line })
      endfor
  endf

  fun! a:cell.__comma_list(words, match, w, line)
    for x in split(a:match[1], '\s*,\s*')
      call add( a:words,  {'word': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts D'.a:line })
    endfor
  endf

  " python like x, b = [a,b]
  fun! a:cell.__first_match_as_comma_list(words, match, w, line)
      if a:match[1] != ''
        for x in split(a:match[1], '\s*,\s*')
          call add( a:words,  {'word': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts E'.a:line})
        endfor
      endif
  endf

  fun! a:cell.__first_match(words, match, w, line)
      if a:match[1] != ''
        call add( a:words,  {'word': a:match[1], 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts F'.a:line})
      endif
  endf

  fun! a:cell.__php_match_comma_list(words, match, w, line)
    " each match can be a comma separated list, found vars will be prefixed by  $
    for match in a:match[1:]
      for x in split(substitute(match, '&', '', 'g'), '\s*,\s*')
        " ($foo = 'bar') - drop default argument
        let x = substitute(x, '\s*=.*$', '', '')
        let w = substitute(x, '\$', '', '')
        call add( a:words,  {'word': w, 'replacement': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts G'.a:line})
      endfor
    endfor
  endf

  fun! a:cell.__ruby_match_comma_list(words, match, w, line) abort
    " each match can be a comma separated list, found vars will be prefixed by  $
    for match in a:match[1:]
      for x in split(substitute(match, '&', '', 'g'), '\s*,\s*')
        let x = substitute(x, '\s*=.*$', '', '')
        let w = substitute(x, '@@\|@\|\$', '', '')
        " no global
        call add( a:words,  {'word': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts H'.a:line})
        if x != w
          " $ @ @@ var
          call add( a:words,  {'word': w, 'replacement': x, 'w': a:w, 'contexts': ['local_var_like'], 'kind': 'Contexts I'.a:line})
        endif
      endfor
    endfor
  endf

  fun! a:cell.local_vars(linenr, plus, minus) abort
    let words = {}
    let linenr = 1
    let lines_max = 500

    let nearby_cursor_lines = 100

    let min = a:linenr - a:minus
    let linenr = a:linenr + a:plus

    if linenr > line('$') | let linenr = line('$') | endif
    if min < 1 | let min = 1 | endif

    " fileptah regex , regex, function handling match results, comment
    " repalce \S by \w or \k
    let regexes_by_filepath = []
    call add(regexes_by_filepath, {'file_pattern': '\.\%(js\|ts\)$'       , 'regex': 'var\s\(\S\+\)\s', 'match_fun' : self.__first_match})
    call add(regexes_by_filepath, {'file_pattern': '\.\%(ts\)$'       , 'regex': '\(\k\+\)\s*\(\s*:\s*\k*\s*\)?*=', 'match_fun':  self.__first_match})
    call add(regexes_by_filepath, {'file_pattern': '\.\%(js\)$'       , 'regex': '\(\k\+\)\s*=[^=]', 'match_fun': self.__first_match})
    call add(regexes_by_filepath, {'file_pattern': '\.\%(js\|ts\|py\|rb\)$', 'regex': '\%(function\|def\)\%(\s\+\(\S\+\)\)\?(\([^)]*\))', 'match_fun': self.__post_function_fun_args, 'w_factor': 1.1})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.vim\)$', 'regex': 'fun\S*!\?\%(\s\+\(\S\+\)\)\?(\([^)]*\))', 'match_fun': self.__post_function_vim})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.vim\)$'      , 'regex': 'let\s\(\S\+\)\s', 'match_fun': self.__first_match})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.vim\)$'      , 'regex': 'for\s\+\(\S\+\)', 'match_fun': self.__first_match})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.ts\)$'      , 'regex': '\<\(\S\+\)(\([^)]*\)', 'match_fun': self.__post_function_fun_args})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.ts\|\.js\)$', 'regex': '(\([^)]*\))\s*[=][>]\s*', 'match_fun': self.__comma_list})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.py\)$'      , 'regex': '\(\w\+\%(\s*, \s*\w\+\)\?\)\s*=','match_fun': self.__first_match_as_comma_list})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.py\)$'      , 'regex': 'for\s\+\(\w\+\%(\s*, \s*\w*\)*\)\s\+in\s', 'match_fun': self.__first_match_as_comma_list})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.py\)$'      , 'regex': 'def\%(\s\+\S\+\)(\([^)]*\))', 'match_fun': self.__first_match_as_comma_list})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.py\)$'      , 'regex': 'as\s\+\(\S\+\)', 'match_fun': self.__first_match})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.php\)$'     , 'regex': '\(\$\S\+\)\s*=', 'match_fun': self.__php_match_comma_list, 'comment': " PHP assignment"})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.php\)$'     , 'regex': 'use(\([^)]*\))', 'match_fun': self.__php_match_comma_list, 'comment': "PHP use(..)"})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.php\)$'     , 'regex': 'function\s\+\([^( \t]\+(\)', 'match_fun': self.__first_match, 'comment': " PHP function name"})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.php\)$'     , 'regex': 'function\%(\s\+[^( \t]*\s*\)\?(\([^)]*\))', 'match_fun': self.__php_match_comma_list, 'comment': " PHP function args"})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.php\)$'     , 'regex': '\s\+as\s\+\([^ \t)]\+\)\%(\s*=>\s*\([^ \t)]\+\)\)\?', 'match_fun': self.__php_match_comma_list,'comment': "PHP foreach" })
    call add(regexes_by_filepath, {'file_pattern': '\%(\.php\)$'     , 'regex': 'global\s\+\([^;]\+\);', 'match_fun': self.__php_match_comma_list,'comment': "PHP global" })
    call add(regexes_by_filepath, {'file_pattern': '\%(\.rb\)$'     , 'regex': '^\s*\([^=()]\{-}\)\s*\%(||\)=', 'match_fun': self.__ruby_match_comma_list,'comment': " Ruby assignment with $ shortcut"})
    call add(regexes_by_filepath, {'file_pattern': '\%(\.rb\)$'     , 'regex': '|\([^|]\+\)|', 'match_fun': self.__ruby_match_comma_list,'comment': " Ruby block vars"})

    let ext   = expand('%:e')
    let bname = bufname('%')

    " let break_on_regex_by_ext = {
    "       \ 'js' : '^function',
    "       \ 'vim' : '^fun'
    "       \ }
    " break_on_regex_by_ext is not worth it for now
    let break_on_regex_by_ext = {}

    let break_on_regex = get(break_on_regex_by_ext, ext, '')

    let regexes_by_filepath = filter(copy(regexes_by_filepath), 'bname =~ v:val["file_pattern"]')
    let words = []

    while linenr >= min
      let line = getline(linenr)
      let w = 10.0 - (abs(a:linenr - linenr) * 1.0 / 30)
      if linenr > a:linenr | let w -=  200 | endif " below cursor is less likely

      if (break_on_regex != '' && line =~  break_on_regex) || linenr < min | break | endif

      for l in regexes_by_filepath
        let match = matchlist(line, l['regex'])
        if len(match) == 0 | continue | endif
        " call helper function to turn matches into words
        call call(l['match_fun'], [words, match, w * get(l, 'w_factor', 1), linenr], self)
      endfor
      let linenr -= 1
    endwhile

    let r = {}
    for w in words
      if has_key(r, w.word)
        if w.w > r[w.word].w | let r[w.word] = w | endif
      else
        let r[w.word] = w
      endif
    endfor


    return r
  endf

  fun! a:cell.l_completions(event) abort

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\w*$')

    let words = self.local_vars(a:event.event.position[1], 40, 200)

    let completions = cells#util#match_by_type2(values(words), word_before_cursor)
    for c in completions
      if has_key(c, 'replacement') | let c.word = c.replacement | call remove(c, 'replacement') | endif
    endfor

    let ext   = expand('%:e')

    " some keyword like ..
    if ext == 'py'
      if a:event.event.line_split_at_cursor[0] =~ '^i'
        call add(completions, {'w': 10, 'word': 'import ', 'kind': 'Context'})
        call add(completions, {'w': 10, 'word': 'self. ', 'kind': 'Context'})
      endif
    endif
    if ext == 'php'
      if a:event.event.line_split_at_cursor[0] =~ '^r'
        call add(completions, {'word': 'require_once ', 'kind': 'Context'})
      endif
    endif

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
      let words[w] = {'word': w, 'w': certainity, 'kind': 'ThisBuffer'}
      let linenr += 1
    endfor

    let completions = cells#util#match_by_type2(values(words), word_before_cursor)
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
  let  a:cell.omit_current_buffer = get(a:cell, 'omit_current_buffer', 1)

  let a:cell.buf_ids_entered_recently = []

  fun! a:cell.l_buf_enter(event)
    let self.buf_ids_entered_recently = [a:event.bufid]+filter(self.buf_ids_entered_recently, 'v:val != a:event.bufid')
  endf

  fun! a:cell.l_completions(event)

    let word_before_cursor = matchstr(a:event.event.line_split_at_cursor[0], '\zs\S*$')
    let words = {}
    let linenr = 1

    let this_buf = bufnr('%')

    for bufnr in range(1, bufnr('$'))
      if bufnr == this_buf && self.omit_current_buffer | continue | endif
      let recently_visited_care = 20
      let add  = (recently_visited_care - index(self.buf_ids_entered_recently[0:recently_visited_care], bufnr)) / recently_visited_care
      let contexts = [ 'rec_buf'.add ]
      for w in self.__line_to_items(join(getbufline(bufnr, 1, '$')," "))
        if (w == word_before_cursor) | continue | endif
        let words[w] = {'word': w, 'w': 0.5, 'contexts': contexts, 'kind': 'AllBuffers'}
        let linenr += 1
      endfor
    endfor

    let completions = cells#util#match_by_type2(values(words), word_before_cursor)
    call self.reply_now(a:event, [{
          \ 'column': a:event.event.position[2] - len(word_before_cursor),
          \ 'completions' : completions
    \ }])
  endf

  return a:cell

endf

" }}}

let s:compl_cache = {}

fun! cells#examples#CompletionsFromCompletionFunction(completions, event, d)
  let findstart = 1
  let pos = getpos('.')
  let pos_new = copy(pos)
  try

    if get(a:d, 'first_char_apply_match_score', 1)
      " Make sure completion function only sees one character, for instance
      " after instance.abc run completion on instance.a
      " then use use supplied s:c.match_store_fun to match functions and set
      " weight
      let cursor_context = cells#util#CursorContext({'position': pos})
      let word_before_cursor = matchstr(cursor_context.line_split_at_cursor[0], '\zs\S*$')
      let  pos_new[2] = (pos[2] - max([0, len(word_before_cursor) -1]))
      call setpos('.', pos_new)
    endif
    let cursor_context_new = cells#util#CursorContext({'position': pos_new})

    if get(a:d, 'spaces_after_cursor', 0)
      let line = getline('.')
      let line_new = line[0:pos_new[2]-2]
      call setline('.', line_new)
    endif


    let r1 = call(a:d['completion-function'], [1, ''])
    if r1 < 0 | return | endif " no completion or cancel silently

    let base = cursor_context_new.line_split_at_cursor[0][r1:]

    let fun_key = string(a:d)
    let sub_key = string(pos_new).base

    if get(a:d, 'use_cache', 1) && has_key(s:compl_cache, fun_key) && s:compl_cache[fun_key][0] == sub_key
      let r2 = s:compl_cache[fun_key][1]
    else
      let r2 = call(a:d['completion-function'], [0, base] )
      let s:compl_cache[fun_key] = [sub_key, r2]
    endif

    if get(a:d, 'first_char_apply_match_score', 1)
      " now apply user supplied match function
      let r2 = cells#util#match_by_type2(r2, word_before_cursor)
    endif

    call add(a:completions, { 'column': r1 +1, 'completions' : r2 })

  finally

    if get(a:d, 'spaces_after_cursor', 0) && exists('line')
      call setline('.', line)
    endif

    call setpos('.', pos)

  endtry

endf

fun! cells#examples#TraitCompletionFromCompletionFunction(cell) abort
  " Usage:
  " call cells#viml#Cell({'traits': ['cells#examples#TraitCompletionFromCompletionFunction'], 'completion-functions': [{'filepath_regex':'\.py$', 'completion-function': 'pythoncomplete#Complete', 'first_char_apply_match_score': 1}])

  let a:cell['completion-functions'] = get(a:cell, 'completion-functions', [])

  fun! a:cell.l_completions(event)
    let bname = bufname('%')
    let active = filter(copy(self['completion-functions']), 'bname =~ v:val["filepath_regex"]')
    let completions = []
    for d in active
      call cells#examples#CompletionsFromCompletionFunction(completions, a:event, d)
    endfor
    call self.reply_now(a:event, completions)
  endf

  return a:cell
endf

fun! cells#examples#PathCompletion(cell) abort
  " vim's file/directory completion is nice, but suffers from
  " PATH=/ro<c-x><c-f> issues not understanding that = is highly unlikely to
  " be part of the path

  let a:cell['completion-functions'] = get(a:cell, 'completion-functions', [])

  fun! a:cell.l_completions(event)
    let file_char = '\%(\w\|[-_.]\)' " c: or ~
    let path_start = '\%(\w:[/\\]\|[~]\|\/\)\?' " foo/bar/
    let paths = '\%('.file_char.'\+[\\/]\)*'    " the part after the last /
    let file = file_char.'*'
    let list = matchlist(a:event.event.line_split_at_cursor[0], '\('.path_start.paths.'\)\('.file.'\)$' )

    if len(list) < 2 || (len(list[1].list[2]) == 0 ) | return | endif
    let dir = list[1]
    let file = list[2]
    if isdirectory(dir)
      let words = map(split(glob(dir.'/*'),"\n"), '{"w": 1, "word": v:val[len(dir)+1:], "kind":"PathCompletion"}')
      let completions = cells#util#match_by_type2(words, file)
      call self.reply_now(a:event, [{
            \ 'column': a:event.event.position[2] - len(file),
            \ 'completions' : completions
      \ }])
    endif
  endf

  return a:cell
endf

fun! cells#examples#LocationsToQF(locations) abort
  let qflist = map(copy(a:locations), 'cells#util#LocationToQFEntry(v:val, {})')
  call setqflist(qflist)
endf

fun! cells#examples#TraitDefinitionsAndUsages(cell) abort
  " VimL user interface for definitions, types, usages events

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
      call cells#util#GotoLocation(flattened[0])
    else
      call cells#examples#LocationsToQF(flattened)
      cope
    endif
  endf

  fun! a:cell.types()
    call self.ask('__got_types', cells#util#CursorContext({'type': 'types', 'position': getpos('.')}))
  endf

  fun! a:cell.type_to_str(t)
    return get(a:t, 'kind', '').' '. a:t.type
  endf

  fun! a:cell.__got_types(request)
    let flattened = cells#util#Flatten1(a:request.results_good)
    if len( flattened ) == 0
      echom "No type"
    else
      for x in flattened
        echom self.type_to_str(x)
      endfor
    endif
  endf

  return a:cell

endf


fun! cells#examples#TraitTestAsk(cell) abort
  " for debugging events
  call cells#traits#Ask(a:cell)
  fun! a:cell.ask_log(event) abort
    debug call self.ask('__results', a:event)
  endf

  fun! a:cell.__results(request) abort
    debug echom string(a:request)
  endf
  return a:cell
endf
