" If there are multiple cells active ask user which one to use ..

fun! cells#viml#emit_to_one#Trait(cell)

  call cells#traits#Ask(a:cell)

  fun! a:cell.l_emit_to_one(event)
    call self.ask('got_list', {'type': 'cell_list', 'selector': {'listens_to': a:event.event.event.type}}, {'event_to_emit': a:event})
  endf

  fun! a:cell.got_list(request)
    let cell_ids = cells#util#Union(a:request.results_good)
    if len(cell_ids) > 1 | echom "multiple handlers for ".a:request.event_to_emit.type. " TODO: implement choice" | endif
    let cell_id = cell_ids[0]
    call g:cells.emit(a:request.event_to_emit, {'id' : cell_id})
  endf

endf
