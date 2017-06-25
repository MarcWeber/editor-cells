" usage: cells#util#ByKeysDefault({}, ['a', 'b'], []) yields {'a': {'b': []}}
fun! cells#util#ByKeysDefault(d, keys, default)
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
  let r = []
  for l in a:lists
    let r += l
  endfor
  return r
endf

fun! cells#util#log(lines) abort
  call cells#Emit(a:event.event, cells#viml#CellsBySelector(a:event.selector))
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

fun! cells#util#match_by_type(list, word, match_types)
  let regexes = []
  let filtered = []

  for t in a:match_types
    if t == 'prefix'
      call add(regexes, ['^'.a:word, 1])
    elseif t == 'prefix_ignore_case'
      call add(regexes, ['^\c'.a:word, 1])
    elseif t == 'ycm'
      " order of chars .., match case, then without match
      call add(regexes, ['^\c'.a:word, 1])
      call add(regexes, ['^\c'.a:word, 1])
    elseif len(a:word) <= 5 && t == 'camel_case_like'
      call add(regexes, [cells#util#CamelCaseLikeMatching(a:word), 1])
    else
      echom 'unkown match_type '.t
      " resort to prefix matching
      call add(regexes, ['^'.a:word, 1])
    endif
  endfor

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

fun! cells#util#CamelCaseLikeMatching(expr)
  let result = ''
  if len(a:expr) > 5 " vim can't cope with to many \( ? and propably we no longer want this anyway
    return 'noMatchDoh'
  endif
  for index in range(0,len(a:expr))
    let c = a:expr[index]
    if c =~ '\u'
      let result .= c.'\u*\l*_\='
    elseif c =~ '\l'
      let result .= '\c'.c.'\l*\%(\l\)\@!_\='
    else
      let result .= c
    endif
  endfor
  return result
endf
