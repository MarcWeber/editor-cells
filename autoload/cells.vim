" GENERAL CELLS INTERAFCE WHICH SHOULD BE IMPLEMENTED IN ALL LANGUAGES
" =====================================================================

if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells
let s:c.cells = get(s:c, 'cells', {})

fun! cells#ProvideAPI()

  if !has_key(s:c, 'emit')

    fun! s:c.emit(event)
      let a:event.origin_network = get(a:event, 'origin_network', 'viml')

      if (has_key(a:event, 'reply_to'))
        let a:event.results  = get(a:event, 'results',  [])
        let a:event.wait_for = get(a:event, 'wait_for', [])
      endif

      call cells#viml#emit_selector({'type': 'emit', 'event': a:event})
    endf

    fun! s:c.kill(selector)
      call self.emit({'type': 'killcells', 'selector': a:selector})
    endf

    fun! s:c.log(lines) abort
      call self.emit({'type': 'log', 'lines': a:lines})
    endf

  endif

endf
