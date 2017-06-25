" VIML IMPLEMENTATIONS of cells support code
" ==========================================

if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells
let s:c.killing = get(s:c, 'killing', {})
let s:c.cells = get(s:c, 'cells', {})
let s:c.last_id = get(s:c, 'last_id', 0)
let s:c.debug   = 1

fun! cells#viml#NextId()
  let s:c.last_id += 1
  return s:c.last_id
endf

fun! cells#viml#Cell(cell) abort
  " adds an unique id
  " registers the cell at cells
  let cell = a:cell
  let cell.id = 'viml:'. cells#viml#NextId()
  let s:c.cells[cell.id] = cell


  fun! cell.l_set_properties(event) abort
    let updated = {}
    for [k,v] in items(a:event.properties)
      if !has_key(self, k) || self[k] != v
        let self[k] = v
        let updated[k] = v
      endif
    endfor
    call cells#Emit({'type': 'properties_changed', 'properties': updated, 'sender': self.id})
  endf

  fun! cell.reply_result(event, r) abort
    let event = {'sender': self.id, 'type': 'reply', 'result': a:r}
    if has_key(a:event, 'request_id')
      let event.request_id = a:event.request_id
    endif
    call cells#Emit(event, {'id': a:event.reply_to})
  endf
  fun! cell.reply_error(event, error) abort
    let event = {'sender': self.id, 'type': 'reply', 'error': a:error}
    if has_key(a:event, 'request_id')
      let event.request_id = a:event.request_id
    endif
    call cells#Emit(event, {'id': a:event.reply_to})
  endf

  if has_key(a:cell, 'traits')
    for t in a:cell.traits
      call call(t, [a:cell])
    endfor
  endif

  fun! cell.kill() abort
    " prevent recursion in VimL
    if has_key(s:c.killing, self.id) | return | endif
    let s:c.killing[self.id] = 1

    " if you want to know when you're killed assign .killed() method
    call remove(s:c.cells, self.id)
    if has_key(self, 'killed')
      call self.killed()
    endif
    call remove(s:c.killing, self.id)
    call cells#Emit({'sender': self.id, 'type': 'killed'})
  endf

  let  cell.l_kill = cell.kill

  return cell
endf

fun! cells#viml#Kill(cell) abort
  call a:cell.kill()
endf

fun! cells#viml#emit_selector(event, selector) abort
  call cells#viml#emit(a:event, cells#viml#CellsBySelector(a:selector))
endf

fun! cells#viml#emit(event, viml_cells) abort
  let listener = 'l_'.a:event.type
  let wait_for = []
  for cell in a:viml_cells
    if has_key(cell, listener)
      " try
      call call(cell[listener], [a:event], cell)
      " catch /.*/
      " a  call call(cell[a:event.type], [a:event], cell)
      "    if has_key(cell, 'reply_to')
      "      call cell.reply_error(a:event, v:exception)
      "    else
      "      echoe v:exception. "\non event\n". string(a:event) ."\non cell\n". cell.id
      "    endif
      "  endtry
      call add(wait_for, cell.id)
    endif
    " elseif has_key(cell, 'any_event')
    " call call(cell[a:event.any_event], a:event, cell)
  endfor
  if has_key(a:event, 'reply_to')
    call cells#Emit({'sender': 'initial', 'type': 'reply', 'wait_for' : wait_for, 'request_id': a:event.request_id}, {'id': a:event.reply_to})
  endif
endf

fun! cells#viml#CellsBySelector(selector) abort
  if type(a:selector) == type({}) 
    if  has_key(a:selector, 'id')
      return [s:c.cells[a:selector.id]]
    elseif has_key(a:selector, 'listens_to')
      let l_listens_to = 
      return map(filter(copy(s:c.cells), 'has_key(v:val, '.string('l_'.a:selector.listens_to).')'), 'v:val.id')
    else
      throw "unkown selector ".string(a:selector)
    endif
  elseif type(a:selector) == type('') && a:selector == 'all'
    return values(s:c.cells)
  else
    throw 'selector '.string(a:selector).' not implemented yet'
  endif
endf


fun! cells#viml#CellCollection()
  let c = cells#viml#Cell({'purpose': 'emit to events to viml cells'})
  fun! c.l_cell_collections(event) abort
    call self.reply_result(a:event, {'prefix': 'vim', 'details': 'default viml cell collection'})
  endf
  fun! c.l_emit(event) abort
    call cells#viml#emit(a:event.event, cells#viml#CellsBySelector(a:event.selector))
  endf
  fun! c.l_cell_kill(event) abort
    for c in cells#viml#CellsBySelector(a:event.selector(a:event.selector))
      call c.kill()
    endfor
  endf
  fun! c.l_cell_list(event)
    call self.reply_result(map(copy(cells#viml#CellsBySelector(a:event.selector)), 'v:val.id'))
  endf
endf

fun! cells#viml#vim8_CoreEvents() abort
  augroup CELLS_VIM8_CORE_EVENTS
  au!
  au BufRead,BufNewFile * call cells#Emit({'type': 'bufnew', 'bufnr': bufnr('%'), 'filename': bufname('%')})
  au BufEnter * call cells#Emit({'type': 'bufenter', 'bufnr': bufnr('%'), 'filename': bufname('%')})
  augroup end
  return c
endf

fun! cells#viml#setupPython(py_cmd)
  if has(a:py_cmd)
  endif
  call cells#viml#vim8_VimEventToPy(a:py_cmd)
endf

fun! cells#viml#vim8_VimEventToPy(py_cmd) abort
  execute a:py_cmd.' import vim'
  execute a:py_cmd.' import cells'
  let cell = cells#viml#Cell({})
  let cell.py_cmd = a:py_cmd
  fun! cell.l_emit(event)
    if a:event.origin_network != self.py_cmd
      execute self.py_cmd.' cells.Emit(vim.eval("a:event"))'
    endif
  endf
endf

fun! cells#viml#CellReplyCollector(cell) abort
  let cell = cells#viml#Cell(a:cell)
  let cell.replies_to_be_waited_for = {}
  let cell.waiting_for = {'initial': 1}
  let cell.results = []

  fun! cell.result(result) abort
    call add(self.results, a:result)
  endf

  fun! cell.killed() abort
    echoe 'cells#viml#CollectRepliesCell, result ready default implementation'
  endf

  fun! cell.process_reply(event) abort
    if has_key(a:event, 'wait_for')
      for cell_id in a:event.wait_for
        if has_key(self.replies_to_be_waited_for, cell_id)
          call self.result(remove(self.replies_to_be_waited_for, cell_id))
        else
          let self.waiting_for[cell_id] = 1
        endif
      endfor
    else
      call self.result(a:event)
    endif
  endf

  fun! cell.l_reply(event) abort
    if !has_key(a:event, 'sender') | echoe 'received reply missing sender key'| endif

    if has_key(self.waiting_for, a:event.sender)
      call remove(self.waiting_for, a:event.sender)
      call self.process_reply(a:event)

      if len(self.waiting_for) == 0
        call self.kill() " .killed should do something with the results
      endif
    else
      let self.replies_to_be_waited_for[a:event.sender] = a:event
    endif
  endf
  return cell
endf
