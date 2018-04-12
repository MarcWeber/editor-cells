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
  if !has_key(cell, 'id')
    let cell.id = 'viml:'. cells#viml#NextId()
  endif
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
    " TODO wait_for_id should be a parameter eventually - think about it
    let a:reply_event.type = 'reply'
    let a:reply_event.sender = self.id
    let a:reply_event.wait_for_id = self.id
    let a:reply_event.selector = {'id': a:event.reply_to}
    if has_key(a:event, 'request_id')
      let a:reply_event.request_id = a:event.request_id
    endif
    return a:reply_event
  endf

  fun! cell.reply_now(event, r) abort
    if has_key(a:event, 'results')
      " only if sender expects results ..
      call add(a:event.results, self.__reply_event(a:event, {'result':  a:r}))
    endif
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

  fun! cell.add_trait(t)
    call add(self.traits, a:t)
    call call(a:t, [self])
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
  call cells#debug#Log(a:event)
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
    elseif  has_key(a:selector, 'ids')
      return map(filter(copy(a:selector.ids), 'has_key(g:cells.cells, v:val)'), 'g:cells.cells[v:val]')
    elseif has_key(a:selector, 'listens_to')
      let l_listens_to = 
      return map(filter(copy(s:c.cells), 'has_key(v:val, '.string('l_'.a:selector.listens_to).')'), 'v:val.id')
    else
      throw "unknown selector ".string(a:selector)
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
  fun! c.l_cell_new_by_name(event)
    if get(a:event, 'network', 'viml') != 'viml' | return | endif
    let cell = call(a:event.name, a:event.args)
    call self.reply_now(a:event, {'id': cell.id})
  endf
  return c
endf

fun! cells#viml#EditorCoreInterface() abort

  let c = cells#viml#Cell({'purpose': 'core interface'})

  augroup CELLS_VIM8_CORE_EVENTS
  au!
  exec 'au BufNew    * call g:cells.cells['. string(c.id) .'].__emit_buffer_event({"type": "editor_bufnew",    "bufid": bufnr("%"), "filename": bufname("%"), "filepath": expand("%:p")})'
  exec 'au BufRead   * call g:cells.cells['. string(c.id) .'].__emit_buffer_event({"type": "editor_bufread",   "bufid": bufnr("%"), "filename": bufname("%"), "filepath": expand("%:p")})'
  exec 'au BufEnter  * call g:cells.cells['. string(c.id) .'].__emit_buffer_event({"type": "editor_bufenter",  "bufid": bufnr("%"), "filename": bufname("%"), "filepath": expand("%:p")})'
  exec 'au BufWritePost  * call g:cells.cells['. string(c.id) .'].__emit_buffer_event({"type": "editor_bufwritepost",  "bufid": bufnr("%"), "filename": bufname("%"), "filepath": expand("%:p")})'
  exec 'au BufUnload * call g:cells.cells['. string(c.id) .'].__emit_buffer_event({"type": "editor_bufunload", "bufid": bufnr("%"), "filename": bufname("%"), "filepath": expand("%:p")})'
  exec 'au CursorMovedI,BufEnter * call g:cells.cells['. string(c.id) .'].__cursor_moved()'
  augroup end

  let c.last_cursor_positions = get(c, 'last_cursor_positions', {})
  let c.buffers_visited_order = get(c, 'buffers_visited_order', [])

  fun! c.__cursor_moved()
    let bufnr = bufnr('%')
    let self.last_cursor_positions[bufnr] = getpos('.')
    let self.buffers_visited_order = [bufnr] + filter(self.buffers_visited_order, 'v:val != bufnr')[:100]
  endf

  fun! c.__editor_buffers()
    let buffers = {}
    let currentnr = bufnr('%')

    for bufnr in range(1, bufnr('$'))
      if !bufexists(bufnr) || !bufwinnr(bufnr) | continue | endif
      let b = {}
      let b['bufid'] = bufnr
      let b['filepath'] = cells#util#FilePathFromFilename(bufname(bufnr))
      let b['vim_filetype'] = getbufvar(bufnr, '&filetype')
      if has_key(self.last_cursor_positions, bufnr)
        let b['last_cursor_pos'] = self.last_cursor_positions[bufnr]
      endif
      let b['modify_state'] = 'todo'
      " TODO safe as bufvar whenever a change happens so that completion code
      " knows which files got updated
      " let b['changenr'] = changenr()
      if bufnr == currentnr
        let current = b
      endif
      let buffers[bufnr] = b
    endfor
    return {'buffers': buffers, 'current': b, 'buffers_visited_order' : self.buffers_visited_order}
  endf

  fun! c.l_editor_commands(event)
    let results = []
    for command in a:event.commands
      if type(command) == type("")
        if command == "write_current_buffer"
          update
          call add(results, "done")
        elseif command == "write_current_buffer_silently"
          silent noautocmd update
        elseif command == "buffers"
          call add(results, self.__editor_buffers())
        else
          throw "unknown command ".string(command)
        endif
      elseif type(command) == type({})
        if has_key(command, 'show_message')
          echom command.show_message
        elseif has_key(command, 'save_as_tmp')
          let ei=&ei| set ei=all| exec 'silent! w! '.fnameescape(g:to_vim) | exec 'set ei='.ei
          call add(results, "done")
        elseif has_key(command, 'lines_of_buf_id')
          " lines_of_buf_id % means current buffer
          call add(results, getbufline(a:event['lines_of_buf_id']), get(a:event, 'from_line', 1), get(a:event, 'to_line', line('$'))))
        elseif has_key(command, 'eval')
          call add(results, eval(command.eval))
        elseif has_key(command, "set_current_line")
          call setline('.', command.set_cursor_line)
          call add(results, "done")
        else
          throw "unknown command ".string(command)
        endif
      endif
    endfor
    call self.reply_now(a:event, results)
  endf

  fun! c.__emit_buffer_event(event_data)
    let a:event_data.filepath = cells#util#FilePathFromFilename(a:event_data.filename)
    " sending events always is almost as cheap as having a selector, so just send those rare events always
    " let a:event_data.selector = {'ids': filter(keys(self.subscriptions), 'has_key(self.subscriptions[v:val], a:event_data.type)') }
    call g:cells.emit(a:event_data)
  endf

  let c.subscriptions = {}

  fun! c.l_editor_features(event)
    call self.reply_now(a:event, ['editor_bufnew', 'editor_bufread', 'editor_bufunload', 'editor_bufenter', 'editor_bufwritepost'])
  endf

  " fun! c.l_editor_subscribe(event)
  "   let self.subscriptions[a:event.sender] = event['subscriptions']
  " endf

  fun! c.l_cell_list(event)
    call self.async_reply(map(copy(cells#viml#CellsBySelector(get(a:event, 'selector', 'all'))), 'v:val.id'))
  endf

endf

fun! cells#viml#EditorVimInterface() abort
  " exposes Vim specific featuers, this is the reference implementation

  let c = cells#viml#Cell({'purpose': 'api to vim features'})

  fun! c.l_get_options(event)
    let r = []
    for o in get(a:event, 'options')
      if o == 'runtimepath'
        let r.runtimepath = &rtp
    endfor
    call self.reply_now(a:event, r)
  endf

endf

fun! cells#viml#CellEchoReply() abort
  let cell = cells#viml#Cell({})
  let s:c.cell_echo_reply = cell
  let cell.py_cmd = a:py_cmd
  fun! cell.l_reply(event)
    echo "got reply ".a:event
  endf
  return cell
endf
