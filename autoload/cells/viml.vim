" VIML IMPLEMENTATIONS of cells support code
" ==========================================

if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells
let s:c.killing = get(s:c, 'killing', {})
let s:c.cells = get(s:c, 'cells', {})
let s:c.last_id = get(s:c, 'last_id', 0)

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
    for [k,v] in items(a:event.event.properties)
      if !has_key(self, k) || self[k] != v
        let self[k] = v
        let updated[k] = v
      endif
    endfor
    call g:cells.emit({'type': 'properties_changed', 'properties': updated, 'sender': self.id})
  endf

  fun! cell.__reply_event(event, reply_event)
    let a:reply_event.type = 'reply'
    let a:reply_event.sender = self.id
    let a:reply_event.selector = {'id': a:event.reply_to}
    if has_key(a:event, 'request_id')
      let a:reply_event.request_id = a:event.request_id
    endif
    return a:reply_event
  endf

  fun! cell.reply_now(event, r) abort
    call add(a:event.results, self.__reply_event(a:event, {'result':  a:r}))
  endf
  fun! cell.reply_error_now(event, r) abort
    call add(a:event.results, self.__reply_event(a:event, {'error':  a:r}))
  endf
  fun! cell.async_reply(event, r) abort
    call g:cells.emit(self.__reply_event(a:event, {'result': a:r} ))
  endf
  fun! cell.async_reply_error(event, r) abort
    call g:cells.emit(self.__reply_event(a:event, {'error': a:r} ))
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
    call g:cells.emit({'sender': self.id, 'type': 'killed'})
  endf

  let  cell.l_kill = cell.kill

  return cell
endf

fun! cells#viml#Kill(cell) abort
  call a:cell.kill()
endf

fun! cells#viml#emit_selector(event) abort
  call cells#viml#emit(a:event, cells#viml#CellsBySelector(get(a:event, 'selector', 'all')))
endf

fun! cells#viml#emit(event, viml_cells) abort
  let listener = 'l_'.a:event.type
  for cell in a:viml_cells
    if has_key(cell, listener)
      " try
      call call(cell[listener], [a:event], cell)
      " catch /.*/
      " a  call call(cell[a:event.type], [a:event], cell)
      "    if has_key(cell, 'reply_to')
      "      call cell.async_error(a:event, v:exception)
      "    else
      "      echoe v:exception. "\non event\n". string(a:event) ."\non cell\n". cell.id
      "    endif
      "  endtry
    endif
    " elseif has_key(cell, 'any_event')
    " call call(cell[a:event.any_event], a:event, cell)
  endfor
endf

fun! cells#viml#CellsBySelector(selector) abort
  if type(a:selector) == type({}) 
    if  has_key(a:selector, 'id')
      if has_key(s:c.cells, a:selector.id)
        return [s:c.cells[a:selector.id]]
      else
        return []
      endif
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
  let c = cells#viml#Cell({'purpose': 'emit emit events to viml cells'})
  fun! c.l_cell_collections(event) abort
    call self.async_reply(a:event, {'prefix': 'vim', 'details': 'default viml cell collection'})
  endf
  fun! c.l_emit(event) abort
    call cells#viml#emit_selector(a:event.event)
  endf
  fun! c.l_cell_kill(event) abort
    for c in cells#viml#CellsBySelector(a:event.selector(a:event.selector))
      call c.kill()
    endfor
  endf
  fun! c.l_cell_list(event)
    call self.async_reply(map(copy(cells#viml#CellsBySelector(a:event.selector)), 'v:val.id'))
  endf
  return c
endf

fun! cells#viml#CoreEvents() abort
  augroup CELLS_VIM8_CORE_EVENTS
  au!
  au BufRead,BufNewFile * call g:cells.emit({'type': 'bufnew', 'bufnr': bufnr('%'), 'filename': bufname('%')})
  au BufEnter * call g:cells.emit({'type': 'bufenter', 'bufnr': bufnr('%'), 'filename': bufname('%')})
  augroup end
endf

let s:path = expand('<sfile>:p:h:h:h')
fun! cells#viml#setupPython(py_cmd) abort
  if has(a:py_cmd)
    execute a:py_cmd.' import sys'
    execute a:py_cmd.' import vim'
    execute a:py_cmd.' sys.path.append(vim.eval("s:path")+"/site-packages/")'
    execute a:py_cmd.' import cells'
    execute a:py_cmd.' import cells.util'
    execute a:py_cmd.' import cells.py'
    execute a:py_cmd.' cells.py.cell_collection.prefix = vim.eval("a:py_cmd")'
    " PY event -> Vim
    execute a:py_cmd.' cells.py.CellPy()'
    execute a:py_cmd.' cells.py.CellPyEventToVim()'
    call cells#viml#vim8_VimEventToPy(a:py_cmd)
  else
    echoe "py ".a:py_cmd." not supported by this Vim"
  endif
endf

fun! cells#viml#vim8_VimEventToPy(py_cmd) abort
  execute a:py_cmd.' import cells'
  let cell = cells#viml#Cell({})
  let cell.py_cmd = a:py_cmd
  fun! cell.l_emit(event)
    if a:event.event.origin_network != self.py_cmd
      let event = copy(a:event.event)
      if has_key(event, 'reply_to')
        let event['results'] = []
        let event['wait_for'] = []
      endif
      execute self.py_cmd.' event=vim.eval("event"); cells.cell_collection.emit_selector(event); cells.util.to_vim(event)'
      for k in ['wait_for', 'results']
        if has_key(g:to_vim, k)
          let a:event.event[k] += g:to_vim[k]
        endif
      endfor
    endif
  endf
endf
