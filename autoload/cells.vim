" GENERAL CELLS INTERAFCE WHICH SHOULD BE IMPLEMENTED IN ALL LANGUAGES
" =====================================================================

if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells
let s:c.last_cell_id = get(s:c, 'last_cell_id', 0)
let s:c.cells = get(s:c, 'cells', {})

let s:c.last_request_id = get(s:c, 'last_request_id', 0)
let s:c.requests = get(s:c, 'requests', {})

" fun! cells#InstantiateFromPath(cell_type, opts)
" endf

fun! cells#Emit(event, ...) abort
  let selector = a:0 > 0 ? a:1 : 'all'
  let a:event.origin_network = 'vim'
  " if a:event.type == 'reply' && !has_key(a:event, 'sender') | throw 'event must have sender key' | endif " fail early
  call cells#viml#emit({'type': 'emit', 'event': a:event, 'selector': selector}, cells#viml#CellsBySelector('all'))
endf

fun! cells#EmitToOne(event, ...) abort
  call cells#viml#emit({'type': 'emit_to_one', 'event': a:event}, cells#viml#CellsBySelector('all'))
endf

fun! cells#Kill(selector)
  call cells#Emit({'type': 'killcells', 'selector': a:selector})
  " returning "" so that it can be called in <c-r> style in insert mode
  return ""
endf

fun! cells#Log(lines) abort
  call cells#Emit({'type': 'log', 'lines': a:lines})
endf
