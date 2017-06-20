
fun! cells#vim8#logging#Trait(cell) abort
  fun a:cell.l_log(event)
    for l in event.loglines
      exec 'echoe '.string(l)
    endfor
  endf
  return a:cell
endf
