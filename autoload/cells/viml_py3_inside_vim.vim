let s:path = expand('<sfile>:p:h:h:h')

fun! cells#viml_py3_inside_vim#BridgeCell() abort
  " python3 asyncio  within vim setup
  " l_emit passes event to Python CellEventToVim inside python_within_vim.py
  " passes events back to Vim.
  " if Python gets stuck waiting in asyncio Vim continues running till timer
  " hits

  let cell = cells#viml#Cell({})

  " cell collection name to be used
  let cell['cell-collection-name'] = get(cell, 'cell-collection-name', 'py3invim')
  let cell.py_cmd = get(cell, 'py_cmd', "python3")
  " keep running python for 10ms, then return to Vim
  let cell.py_async_timeslot_ms = get(cell, 'py_async_timeslot', 5)
  " run vim every 10 ms
  let cell.vim_timer_frequency_ms      = get(cell, 'vim_timer_frequency_ms', 10)
  let cell.vim_timer_frequency_ms_transition = get(cell, 'vim_timer_frequency_ms_transition', 50) " even polling eats up your cpu
  let cell.vim_timer_frequency_ms_idle = get(cell, 'vim_timer_frequency_ms_idle', 1000) " even polling eats up your cpu

  let cell.last_lent_counter = 0
  let cell.timer_freq = 0

  if !has(cell.py_cmd) | throw 'python '. cell.py_cmd.' required' | endif
  if !has('timers') | throw 'Vim with +timers feature required'   | endif " there are workarounds, but they might be ugly

  " prepare pyhton
  let py = [
        \ 'import sys',
        \ 'import vim',
        \ 'import asyncio',
        \ 'sys.path.append(vim.eval("s:path")+"/py3/site-packages/")',
        \ 'import cells.asyncio as cells_a',
        \ 'import cells.util',
        \ 'import traceback',
        \ 'import cells.python_within_vim',
        \ 'cells.python_within_vim.setup(vim.eval("cell[\"cell-collection-name\"]"))'
        \ ]

  execute cell.py_cmd.' '.join(py, "\n")

  fun! cell.l_emit(event) abort
    let self.last_lent_counter = 0
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
    execute self.py_cmd.' cells.python_within_vim.process_event(vim.eval("event"))'
    call self.process_python_asyncio(self.py_async_timeslot_ms)
  endf

  fun! cell.remove_timer()
      " disable timer
      if has_key(self, 'timer')
        call timer_stop(self.timer)
        call remove(self, 'timer')
      endif
  endf

  fun! cell.process_python_asyncio(py_async_timeslot_ms) abort
    execute self.py_cmd.' cells.util.to_vim(cells.python_within_vim.process('. a:py_async_timeslot_ms .'))'
    if g:to_vim == 0
      call self.remove_timer()
    else
      let ms = self.last_lent_counter > 150  ? self.vim_timer_frequency_ms_idle : ( self.last_lent_counter < 20 ? self.vim_timer_frequency_ms : self.vim_timer_frequency_ms_transition)
      if !has_key(self, 'timer') || self.timer_freq != ms
        call self.remove_timer()
        let self.timer = timer_start(ms, function(self.process_python_asyncio_timer, [], self) , {"repeat": -1})
      endif
    endif
  endf

  fun! cell.process_python_asyncio_timer(timer_id) abort
    " only have high timer frequency is there were events sent to python lately
    let self.last_lent_counter = self.last_lent_counter+1
    call self.process_python_asyncio(self.py_async_timeslot_ms)
  endf

  fun! cell.cell_new_by_name(dict)
    let d = copy(a:dict)
    let d.origin_network = 'viml'
    let d.type = 'cell_new_by_name'
    let d.selector = {'id': self['cell-collection-name']."-collection"}
    execute self.py_cmd.' cells.python_within_vim.process_event(vim.eval("d"))'
    call self.process_python_asyncio(0)
  endf

  return cell
endf
