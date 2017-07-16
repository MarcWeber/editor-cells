if !exists('g:cells') | let g:cells = {} | endif | let s:c = g:cells

fun! cells#vim8#ftdetect#Trait(cell) abort

  call cells#traits#Ask(a:cell)

  fun! a:cell.l_bufenter(event)
    if getbufvar(a:event.bufnr, "&filetype") == ""
      call self.ask( 'ftdetect_results', {'type': 'ftdetect', 'bufnr': a:event.event.bufnr, 'filename' : filename(a:event.bufnr)})
    endif
  endf

  fun! a:cell.ftdetect_results(request)
    exec 'set ft='.a:request.results_good[0]
    if (len(a:request.results_good[0]))
      " TODO: aske user what to do..
      echoe 'got multiple filetype replies'
    endif
  endf

endf
