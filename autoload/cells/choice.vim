fun! vim8#choice#Trait(cell)

  call cells#traits#Ask(a:cell)

  fun! a:cell.l_choice(event)
    let nr = 1
    for item in a:event.choices
      echom nr.': '.item.line
    endfor
    let chosen = input(get(a:event, 'title', ''). ' Your choice: ')
    call self.reply_result(a:event, a:event.choices[chosen-1].return)
  endf

  fun! a:cell.got_list(request)
    let cell_ids = cells#util#Union(a:request.results_good)
    if len(cell_ids) > 1 | echom "multiple handlers for ".a:request.event_to_emit.type. " TODO: implement choice" | endif
    let cell_id = cell_ids[0]
    call emit#Emit(a:request.event_to_emit, {'id' : cell_id})
  endf

endf
