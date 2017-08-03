" vim8 specific implementations of VimL cells
"
" TODO implement same for NeoVim

fun! cells#vim8#CellCollectionExternalProcessTrait(cell) abort

  if !has_key(a:cell, 'cmd') |  throw "cell requires key commandline" | endif

  if !has_key(a:cell, 'cell-collection-name')
    let a:cell['cell-collection-name'] = 'cells#vim8#CellCollectionExternalProcess'.cells#viml#NextId()
  endif

  fun! a:cell.l_emit(e) abort
    call ch_sendraw(self.job, json_encode(a:e.event)."\n")
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
    let self.job = job_start(self.cmd, {'callback': function(self.cb, [], self)})
    call ch_sendraw(self.job, json_encode({'cell-collection-name': self['cell-collection-name']})."\n")
  endf

  call a:cell.cmd_restart()

  return a:cell

endf
