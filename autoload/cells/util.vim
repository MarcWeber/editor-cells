if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells

" usage: cells#util#ByKeysDefault({}, ['a', 'b'], []) yields {'a': {'b': []}}
fun! cells#util#ByKeysDefault(d, keys, default) abort
  let d = a:d
  for i in a:keys
    let d[i] = get(d, i, {})
  endfor
  let lk = a:keys[-1]
  let d[lk] = get(d, lk, a:default)
  return d[lk] 
endf

fun! cells#util#Union(lists) abort
  let d = {}
  for l in a:lists
    for k in l | let d[k] = 1 | endfor
  endfor
  return keys(d)
endf

fun! cells#util#Flatten1(lists) abort
  let g:lists = a:lists
  let r = []
  for l in a:lists
    let r += l
  endfor
  return r
endf

fun! cells#util#match_by_type2(list, word) abort
  let list = a:list
  let Fun = s:c.match_store_fun(a:word)
  for c in list
    let c.w = get(c, 'w', 0.9) * call(Fun, [c.word])
  endfor
  call filter(list, 'v:val.w > 0')
  return a:list
endf

" fun! cells#util#match_by_type_Test()
"   let list = []
"   call add(list, {'word': 'abc_BAR'})
"   call add(list, {'word': 'abcBAR'})
"   call add(list, {'word': 'zarumba'})

"   echo cells#util#match_by_type(list, 'abc', ['prefix'])
"   echo cells#util#match_by_type(list, 'za', ['prefix'])
"   echo cells#util#match_by_type(list, 'abc', ['ycm'])
"   echo cells#util#match_by_type(list, 'aB', ['camel_case_like'])
" endf
" call cells#util#match_by_type_Test()

fun! cells#util#match_by_type(list, word, match_types) abort
  " deprecated
  let regexes = []
  let filtered = []

  if index(a:match_types, 'prefix') >= 0
    call add(regexes, ['^'.a:word, 1])
  endif
  if index(a:match_types, 'prefix_ignore_case') >= 0
    call add(regexes, ['^\c'.a:word, 1])
  endif
  if index(a:match_types, 'ycm_like') >= 0
    " order of chars .., match case, then without match
    call add(regexes, ['^'.join(split(a:word, '\zs'), '.*'), 1])
    call add(regexes, ['^\c'.join(split(a:word, '\zs'), '.*'), 0.9])
  endif
  if len(a:word) <= 5 && index(a:match_types, 'camel_case_like') >= 0
    call add(regexes, ['^'.cells#util#CamelCaseLikeMatching(a:word), 1])
  endif
  if (len(regexes) == 0)
    echom 'no known match type found in '.string(a:match_types)
    " resort to prefix matching
    call add(regexes, ['^'.a:word, 1])
  endif

  for l in a:list
    let l.certainity = get(l, 'certainity', 1.0)
    let c = 0
    for r in regexes
      if l.word =~ r[0]
        if r[1] > c | let c = r[1] | endif
      endif
    endfor
    if c > 0 | call add(filtered, l) | endif
  endfor
  " The code showing completions will sort again
  " call sort(filtered, {a, b -> a.certainity - b.certainity})
  return filtered
endf

fun! cells#util#CamelCaseLikeMatching(expr) abort
  let result = ''
  if len(a:expr) > 5 " vim can't cope with to many \( ? and propably we no longer want this anyway
    return a:expr
  endif
  for index in range(0,len(a:expr))
    let c = a:expr[index]
    if c =~ '\u'
      let result .= c.'\u*\l*[_-]\?'
    elseif c =~ '\l'
      let result .= '\c'.c.'\l*[-_]\?'
    else
      let result .= c
    endif
  endfor
  return result
endf

fun! cells#util#TestCamelCaseLikeMatching()
  echom 'should all be 1'
  echom 'ab' =~ '^'.cells#util#CamelCaseLikeMatching('ab')
  echom 'a_b' =~ '^'.cells#util#CamelCaseLikeMatching('ab')
  echom 'az_boo' =~ '^'.cells#util#CamelCaseLikeMatching('ab')
  echom 'az-boo' =~ '^'.cells#util#CamelCaseLikeMatching('ab')
  echom 'Az_Boo' =~ '^'.cells#util#CamelCaseLikeMatching('AB')
  echom 'Az-Boo' =~ '^'.cells#util#CamelCaseLikeMatching('AB')
  echom 'AzBoo' =~ '^'.cells#util#CamelCaseLikeMatching('AB')
  echom 'AZ-Boo' =~ '^'.cells#util#CamelCaseLikeMatching('AB')
  echom 'test done'
endf
" call cells#util#TestCamelCaseLikeMatching()

fun! cells#util#ToVim(x) abort
  let g:to_vim = a:x
endf

fun! cells#util#Call(f, args) abort
  let r = call(a:f, a:args)
  return r
endf

fun! cells#util#EmitReturn(event) abort
  try
    call g:cells.emit(a:event)
  catch /.*/
    call cells#debug#Log([v:exception, v:throwpoint])
    echom 'exception '.v:exception
    echom 'exception '.v:throwpoint
    throw v:exception
  endtry
  return a:event
endf

" from tlib
function! cells#util#OutputAsList(command) abort
    let redir_lines = ''
    redir =>> redir_lines
    silent! exec a:command
    redir END
    return split(redir_lines, '\n')[2:-2]
endf

fun! cells#util#FilePathFromFilename(name)
  return a:name
endf

fun! cells#util#CursorContext(event)
  let col_m1 = a:event.position[3]
  let line   = getline('.')
  let a:event['bufid'] = bufnr('%')
  let a:event['filename'] = bufname('%')
  let a:event['cword'] = expand('<cword>')
  " let a:event['filepath'] = cells#util#FilePathFromFilename(a:event['filename'])
  let a:event['filepath'] = expand('%:p')
  let a:event['line_split_at_cursor'] = [line[0: a:event.position[2]-2], line[a:event.position[2]-1:]]
  let a:event['offset'] = line2byte(line('.')) + col('.') - 1
  return a:event
endf

fun! cells#util#LocationToQFEntry(source, target)
  let r = a:target
  let r['filename'] = a:source.filepath
  if has_key(a:source, 'line')
    let r['lnum'] = a:source.line
    if has_key(a:source, 'column')
      let r['col'] = a:source.column
    endif
  elseif has_key(a:source, 'offset')
    call cells#util#OffsetToLineCol(a:source.filepath, a:source.offset, r)
  else
    throw "no line given in ".string(a:source)
  endif
  return r
endf

fun! cells#util#GotoLocation(event)
  if expand('%:p') != a:event.filepath
    exec 'e '.fnameescape(a:event.filepath)
  endif
  if has_key(a:event, 'offset')
    exec 'goto '.a:event.offset
  else
    if has_key(a:event, 'line') | exec a:event.line | endif
    if has_key(a:event, 'column')
      exec 'normal '.a:event.column.'|'
    endif
  endif
endf

fun! cells#util#MatchScoreFunction(word)
  let c = {}
  let c.word = word
  let c.regex_camel_case_like = '^'.cells#util#CamelCaseLikeMatching(a:word)
  let c.regex_prefix = '^'. c.word
  let c.regex_ignore_case = '^\v'. c.word

  fun! c.score(s)

    if a:s =~ self.regex_camel_case_like
      return 2

    if a:s =~ self.regex_prefix
      return 1.5

    if a:s =~ self.regex_ignore_case
      return 0.5

    return 0
  endf

  return function(c.score, [], c)
endf

fun! cells#util#OffsetToLineCol(filepath, offset, target)
  let lines = readfile(a:filepath, "b")
  let offset_left = a:offset
  for lnum in range(0, len(lines)-1)
    let l = lines[lnum]
    let offset_left_next = offset_left - len(l)-1
    if offset_left_next < 0
      let a:target['lnum'] = lnum + 1
      let a:target['col'] = offset_left
      break
    endif
    let offset_left = offset_left_next
  endfor
endf
