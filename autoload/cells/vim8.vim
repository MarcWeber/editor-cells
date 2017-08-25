" vim8 specific implementations of VimL cells
"
" TODO: implement same for NeoVim
" TODO: quit process when Vim quits

fun! cells#vim8#CellCollectionExternalProcessTrait(cell) abort

  if !has_key(a:cell, 'cmd') |  throw "cell requires key commandline" | endif

  " Debug stdin/out by setting pipe_dump_prefix

  if !has_key(a:cell, 'cell-collection-name')
    let a:cell['cell-collection-name'] = 'cells#vim8#CellCollectionExternalProcess'.cells#viml#NextId()
  endif

  fun! a:cell.l_emit(event) abort
    if (a:event.event.origin_network == self['cell-collection-name']) | return | endif
    if has_key(a:event.event, 'reply_to')
      let wait_for_id__for_requesting_cell = 'viml-id-'.cells#viml#NextId()
      call add(a:event.event.wait_for, wait_for_id__for_requesting_cell)

      let event = copy(a:event.event)
      let event['wait_for_id__for_requesting_cell'] =  wait_for_id__for_requesting_cell
      call remove(event, 'results')
      call remove(event, 'wait_for')
    else
      let event = a:event.event
    endif
    " if  confirm(string(event), "y\nn")
      call self.send_json(event)
    " endif 
  endf

  fun! a:cell.l_restart_cmd()
    call self.cmd_restart()
  endf

  fun! a:cell.kill()
    call self.cmd_stop()
  endf

  fun! a:cell.cb(channel, str)
    if a:str =~ '^{'
      call cells#util#Log('got json str '.a:str)
      let event = json_decode(a:str)
      if has_key(event, 'reply_to')
        let wait_for_id__for_requesting_cell = event.wait_for_id__for_requesting_cell
        call remove(event, 'wait_for_id__for_requesting_cell')
      endif
      call g:cells.emit(event)
      if has_key(event, 'reply_to')
        let event_ = {'origin_network': 'viml', 'type': 'reply', 'request_id': event['request_id'], 'wait_for_id' : wait_for_id__for_requesting_cell,  'results': event.results, 'wait_for': event.wait_for, 'selector': {'id': event.reply_to}}
        call self.send_json(event_)
      endif
    else
      " looks like error lines
      echoe a:str
    endif
  endf

  fun! a:cell.send_json(thing) abort
    call ch_sendraw(self.job, json_encode(a:thing)."\n")
  endf

  fun! a:cell.cmd_stop() abort
    if has_key(self, 'job') | call job_stop(self.job) | endif
  endf

  fun! a:cell.cmd_restart() abort
    call self.cmd_stop()

    let cmd = self.cmd
    " if has_key(self, 'pipe_dump_prefix')
    "   let cmd = 'tee /tmp/'. self.pipe_dump_prefix .'-in | '.join( cmd, ' ').' | tee /tmp/'. self.pipe_dump_prefix .'-out'
    "   echom cmd
    "   " throw 'bad'
    " endif

    let self.job = job_start(cmd, {'callback': function(self.cb, [], self), 'stoponexit': 1})
    call self.send_json({'cell-collection-name' : self['cell-collection-name'], 'receiving-cell-id': self.id})
  endf

  fun! a:cell.cell_new_by_name(dict)
    let d = copy(a:dict)
    let d.origin_network = 'viml'
    let d.type = 'cell_new_by_name'
    let d.selector = {'id': self['cell-collection-name']."-collection"}
    call self.send_json(d)
  endf

  call a:cell.cmd_restart()

  return a:cell

endf
