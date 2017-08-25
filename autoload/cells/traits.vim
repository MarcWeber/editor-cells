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

    fun! request.process_wait_for(wait_for_id)
      if has_key(self.replies_to_be_waited_for, a:wait_for_id)
        let event = remove(self.replies_to_be_waited_for, a:wait_for_id)
        call self.process_event_waited_for()
      else
        let self.waiting_for[a:wait_for_id] = 1
      endif
    endf
    fun! request.process_event_waited_for(event)
      for wait_for in get(a:event, 'wait_for', [])
        call self.process_wait_for(wait_for)
      endfor

      if has_key(a:event, 'result') || has_key(a:event, 'error')
        call add(self.results, a:event)
      endif
      if has_key(a:event, 'results')
        let self.results = self.results + a:event.results
      endif
    endf
    let request_id = 'viml-'. cells#viml#NextId()
    let self.requests[request_id] = request
    let a:event.request_id = request_id

    let request.cb = a:cb
    let request.event = a:event

    let request.replies_to_be_waited_for = {}
    let request.cancel = 0
    let request.waiting_for = {}

    " emit event watiing for replies, calling cb when ready
    let a:event.reply_to = self.id
    call cells#util#Log('request_id: '.request_id.' vor emit '.string(request))
    call g:cells.emit(a:event)
    call cells#util#Log('request_id: '.request_id.' vor after emit '.string(request))
    let request.results = a:event.results
    for wait_for_id in a:event.wait_for
      call request.process_wait_for(wait_for_id)
    endfor
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
    let request_id = a:event.request_id
    let request = self.requests[request_id]
    call cells#util#Log('l_reply request_id '.request_id.' request '.string(request))
    call cells#util#Log('l_reply request_id '.request_id.' event '.string(a:event))
    if has_key(request.waiting_for, a:event.wait_for_id)
      call remove(request.waiting_for, a:event.wait_for_id)
      call request.process_event_waited_for(a:event)
    else
      let request.replies_to_be_waited_for[a:event.wait_for_id] = a:event
    endif

    call self.__check_request_finished(request)
    call cells#util#Log('l_reply request_id '.request_id.' finsihed request fun finished '.string(request))
  endf


endf
