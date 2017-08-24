" vim8 specific implementations of VimL cells
"
" TODO: implement same for NeoVim
" TODO: quit process when vim quits

fun! cells#vim8#CellCollectionExternalProcessTrait(cell) abort

  if !has_key(a:cell, 'cmd') |  throw "cell requires key commandline" | endif

  " Debug stdin/out by setting pipe_dump_prefix

  if !has_key(a:cell, 'cell-collection-name')
    let a:cell['cell-collection-name'] = 'cells#vim8#CellCollectionExternalProcess'.cells#viml#NextId()
  endif

  fun! a:cell.l_emit(event) abort
    if has_key(a:event.event, 'reply_to')
      let event = copy(a:event.event)
      let event['wait_for_id__for_requesting_cell'] =  'viml-id-'.cells#viml#NextId()
      call add(event.wait_for, event['wait_for_id__for_requesting_cell'])
    else
      let event = a:event.event
    endif
    call ch_sendraw(self.job, json_encode(a:event)."\n")
  endf

  fun! a:cell.l_restart_cmd()
    call self.cmd_restart()
  endf

  fun! a:cell.kill()
    call self.cmd_stop()
  endf

  fun! a:cell.cb(channel, str)
    if a:str =~ '^{'
      let event = json_decode(a:str)
      call g:cells.emit(event)
    else
      " looks like error lines
      echom a:str
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
    if has_key(self, 'pipe_dump_prefix')
      let cmd = 'tee /tmp/'. self.pipe_dump_prefix .'-in | '.join( cmd, ' ').' | tee /tmp/'. self.pipe_dump_prefix .'-out'
    endif
    echom cmd

    let self.job = job_start(cmd, {'callback': function(self.cb, [], self), 'stoponexit': 1})
    call ch_sendraw(self.job, json_encode({'set-cell-collection-name': self['cell-collection-name']})."\n")
  endf

  call a:cell.cmd_restart()

  return a:cell

endf
