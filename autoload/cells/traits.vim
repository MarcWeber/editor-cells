" commonly used code for cells

fun! cells#traits#Ask(cell) abort
  " usage:
  " call cells#traits#Ask(cell)
  " 
  " fun! cell.DoStuff()
  "    call self.ask('handle_result', {'type': 'event'}, {})
  " endf
  " fun! cell.handle_result(request)
  "   let first_result = a:request.results_good[0]
  " endf

  let a:cell.requests = get(a:cell, 'requests', {})

  fun! a:cell.cancel_request(request_id) abort
    if !has_key(self.requests, a:request_id) | return |endif
    let request = remove(self.requests, a:request_id)
    for id in keys(request.waiting_for)
      call g:cells.emit({'type': 'cancel_request', 'reuqest_id': a:request_id}, {'id': id})
    endfor
  endf

  fun! a:cell.cancel_ask(cb, event, ...) abort
    let request = a:0 > 0 ? a:1 : {}
    " if a request of same type has been running cancel it
    " then restart. Useful for stuff like completions. When starting a new
    " completion don't wait for old results
    for [k,i] in items(self.requests)
      if has_key(i,'type') && get(i, 'type') == request.type
        call self.cancel_request(k)
      endif
    endfor
    call self.ask(a:cb, a:event, request)
  endf

  fun! a:cell.ask(cb, event, ...) abort
    let request = a:0 > 0 ? a:1 : {}
    let request.cb = a:cb
    let request.event = a:event

    let request.replies_to_be_waited_for = {}
    let request.cancel = 0
    let request.waiting_for = {}

    " emit event watiing for replies, calling cb when ready
    let a:event.request_id = cells#viml#NextId()
    let a:event.reply_to = self.id

    let self.requests[request.event.request_id] = request

    call g:cells.emit(a:event)
    for id in a:event.wait_for
      let request.waiting_for[id] = 1
    endfor
    let request.results = a:event.results
    call self.__check_request_finished(request)
    return a:event.request_id
  endf

  fun! a:cell.__check_request_finished(request) abort
    if len(a:request.waiting_for) == 0 && len(a:request.replies_to_be_waited_for) == 0
      " let g:cells['traces'] = get(g:cells, 'traces', [])
      call remove(self.requests, a:request.event.request_id)
      if (!a:request.cancel)
        let a:request.results_good  = map(filter(copy(a:request.results), 'has_key(v:val, "result")'), 'v:val.result')
        let a:request.errors = map(filter(copy(a:request.results), 'has_key(v:val, "error")'), 'v:val.error')
        call call(self[a:request.cb], [a:request], self)
      endif
    endif
  endf

  fun! a:cell.l_reply(event) abort
    if !has_key(a:event, 'sender') | echoe 'received reply missing sender key'| endif
    let request_id = a:event.request_id

    let request = self.requests[request_id]

    if has_key(request.waiting_for, a:event.sender)

      call remove(request.waiting_for, a:event.sender)

      for cell_id in get(a:event, 'wait_for', [])
        if has_key(request.replies_to_be_waited_for, cell_id)
          call add(request.results, remove(request.replies_to_be_waited_for, cell_id))
        else
          call add(request.wait_for, cell_id)
        endif
      endfor
      if has_key(a:event, 'result') || has_key(a:event, 'error')
        call add(request.results, a:event)
      endif
    else
      let request.replies_to_be_waited_for[a:event.sender] = a:event
    endif

    call self.__check_request_finished(request)
  endf


endf
