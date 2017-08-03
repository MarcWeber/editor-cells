" Py 3 with external process supports asyncio which is why I recommend using
" py3 instead of this, however this can access 'import vim' easily, thus you
" have access to raw buffers

let s:path = expand('<sfile>:p:h:h:h')
fun! cells#viml_py_inside_vim#setupPython(py_cmd) abort
  if has(a:py_cmd)
    let py = [
          \ 'import sys',
          \ 'import vim',
          \ 'sys.path.append(vim.eval("s:path")+"/py2/site-packages/")',
          \ 'import cells',
          \ 'import cells.util',
          \ 'import cells.py',
          \ 'import traceback',
          \ 'cells.py.cell_collection.prefix = vim.eval("a:py_cmd")'
          \]
    execute a:py_cmd.' '.join(py, "\n")
    " PY event -> Vim
    execute a:py_cmd.' cells.py.CellPy()'
    execute a:py_cmd.' cells.py.CellPyEventToVim()'
    call cells#viml_py_inside_vim#vim8_VimEventToPy(a:py_cmd)
  else
    echoe "py ".a:py_cmd." not supported by this Vim"
  endif
endf

fun! cells#viml_py_inside_vim#vim8_VimEventToPy(py_cmd) abort
  execute a:py_cmd.' import cells'
  let cell = cells#viml#Cell({})
  let cell.py_cmd = a:py_cmd
  fun! cell.l_emit(event)
    if a:event.event.origin_network != self.py_cmd
      let event = copy(a:event.event)
      if has_key(event, 'reply_to')
        let event['results'] = []
        let event['wait_for'] = []
      endif
      execute self.py_cmd.'  cells.util.to_vim(cells.util.emit_return(vim.eval("event")))'
      for k in ['wait_for', 'results']
        if has_key(g:to_vim, k)
          let a:event.event[k] += g:to_vim[k]
        endif
      endfor
    endif
  endf
endf

