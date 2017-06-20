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
