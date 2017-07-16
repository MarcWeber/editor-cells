set nocompatible
filetype indent plugin on | syn on

" fun! G() abort
"   for c in g:calls
"     call call('call', c)
"   endfor
" endf

set hidden
" sample vimrc
exec 'set rtp+='.fnameescape(expand('<sfile>:p:h'))

" VimL emit implementation
call cells#viml#CellCollection()
" Editor core events implementation
call cells#viml#CoreEvents()
call cells#ProvideAPI()

" PY <-> PY3 <-> VIM
for py_cmd in  ['python' ,'python3']
  if has(py_cmd)
    call cells#viml#setupPython(py_cmd)
  endif
endfor

if 0
  let logger = cells#viml#Cell({})
  fun! logger.l_emit(event)
    echom string(a:event)
  endf
endif

" call cells#viml#vim8_completions#Cell({})
" call cells#viml#vim8_mappings#Cell({})

" you can create multiple cells as you like listening to events
call cells#viml#Cell({'traits': ['cells#vim8#logging#Trait']})
call cells#viml#Cell({'traits': ['cells#vim8#ftdetect#Trait', 'cells#vim8#mappings#Trait', 'cells#vim8#signs#Trait', 'cells#vim8#quickfix#Trait', 'cells#vim8#completions#Trait']})
" , 'cells#vim8#choice#Trait', 'cells#vim8#emit_to_one#Trait', 

fun! SetupVimTestCells()
  call append('$', ['','','',''])

  let traits = ['cells#examples#TraitTestMappings', 'cells#examples#TraitTestSigns', 'cells#examples#TraitTestQuickfix', 'cells#examples#TraitTestCompletion']
  call cells#viml#Cell({'traits': traits})

  sp | enew
  call append('$', [
        \ 'there should be one sign at buffer 1',
        \ 'quickfix list should have one line with text ',
        \ ])
  noremap <F10> :qa!<cr>
endf


fun! SetupPyTestCells()
if has('python')
py << END
import cells.examples
cells.examples.Completion()
cells.examples.Mappings()
cells.examples.Signs()
cells.examples.Quickfix()
END
endif
endf

" echom 'use the following examples call SetupVimTestCells | call SetupVimTestCells()'


" if cells#examples#vim_dev#GotoError('first') | cfirst | endif
nnoremap <esc>. :cnext<cr>
