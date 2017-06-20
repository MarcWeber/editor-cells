" commonly used code for cells

fun! cells#traits#Ask(cell) abort
  " usage:
  " call cells#traits#Ask(cell)
  " 
  " fun! cell.DoStuff()
  "    call self.ask({'event': {event question}, 'cb': 'handle_result', 'cb_args': .., 'selector': ..})
  " endf
  " fun! cell.handle_result(request, payload1)
  "   let first_result = a:request.results_good[0]
  " endf

  let a:cell.requests = get(a:cell, 'requests', {})

  fun! a:cell.ask(request)
    let a:request.replies_to_be_waited_for = {}
    let a:request.waiting_for = {'initial': 1}
    let a:request.results = []

    " emit event watiing for replies, calling cb when ready
    let a:request.event.request_id = cells#viml#NextId()
    let a:request.event.reply_to = self.id

    let self.requests[a:request.event.request_id] = a:request
    call cells#Emit(a:request.event, get(a:request, 'selector', 'all'))
  endf

  fun! a:cell.process_reply(request, event) abort
    if has_key(a:event, 'wait_for')
      for cell_id in a:event.wait_for
        if has_key(a:request.replies_to_be_waited_for, cell_id)
          call add(a:request.results, remove(a:request.replies_to_be_waited_for, cell_id))
        else
          let a:request.waiting_for[cell_id] = 1
        endif
      endfor
    else
      call add(a:request.results, a:event)
    endif
  endf

  fun! a:cell.l_reply(event) abort
    if !has_key(a:event, 'sender') | echoe 'received reply missing sender key'| endif
    let request_id = a:event.request_id

    let request = self.requests[request_id]

    if has_key(request.waiting_for, a:event.sender)
      call remove(request.waiting_for, a:event.sender)
      call self.process_reply(request, a:event)

      if len(request.waiting_for) == 0
        call remove(self.requests, request_id)
        let request.results_good  = map(filter(copy(request.results), 'has_key(v:val, "result")'), 'v:val.result')
        let request.errors = map(filter(copy(request.results), 'has_key(v:val, "error")'), 'v:val.error')
        call call(self[request.cb], [request], self)
      endif
    else
      let request.replies_to_be_waited_for[a:event.sender] = a:event
    endif
  endf

endf

" fun! cells#traits#Hooks(cell) abort
"   " add hooks feature to cell
"   " for instance a trait could require cleanup when killed
"   " so allow each extension of a cell to receive a killed hook call

"   let a:cell.hooks = get(a:cell, 'hooks', {})

"   fun a:cell.killed()
"     call self.call_hooks('killed')
"   endf

"   fun! a:cell.call_hooks(name, args) abort
"     for k in get(self.hooks, a:name, [])
"       call call(self[k], a:args, self)
"     endfor
"   endf

"   let  cell.set_properties2 = cell.set_properties
"   fun! cell.l_set_properties(event) abort
"     call self.set_properties2(a:event.properties)
"     call self.call_hooks('properties_changed')
"   endf

"   return a:cell
" endf
