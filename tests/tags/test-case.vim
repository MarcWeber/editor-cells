" vim -u test-case.vim
set nocompatible
filetype indent plugin on | syn on
syntax on

for file in ['/tmp/log-vim','/tmp/log-python']
  if file_readable(file) | call delete(file) | endif
endfor

set hidden
exec 'set rtp+='.fnameescape(expand('<sfile>:p:h:h:h'))

call cells#viml#CellCollection()
call cells#viml#EditorCoreInterface()
call cells#ProvideAPI()


call cells#viml#Cell({'traits': ['cells#viml#logging#Trait']})
call cells#viml#Cell({'traits': ['cells#viml#ftdetect#Trait', 'cells#viml#mappings#Trait', 'cells#viml#signs#Trait', 'cells#viml#quickfix#Trait']})
let cell_completion = cells#viml#Cell({'traits': ['cells#viml#completions#Trait']})
let cell_completion.limit = 10

fun! SetupPy3AsyncioTestCellsWithinVim() " [python3 within_vim]
  let g:bridge_cell = cells#viml_py3_inside_vim#BridgeCell()

  " call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.examples.CompletionBasedOnFiles', 'args': [], 'kwargs': {'id': 'CompletionBasedOnFiles'}})
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.examples.CompletionTAGS', 'args': [], 'kwargs': {}})
endf

call SetupPy3AsyncioTestCellsWithinVim()

inoremap <s-space> <c-r>=g:cells.emit({'type': 'complete', 'completeopt' : 'menu,menuone,preview', 'position': getpos('.'), 'limit': 20, 'match_types' : ['prefix', 'ycm_like', 'camel_case_like', 'ignore_case', 'last_upper']})<cr>
inoremap <f3> <c-r>=g:cells.emit({'type': 'complete', 'completeopt' : 'menu,menuone,preview', 'position': getpos('.'), 'limit': 20, 'match_types' : ['prefix', 'ycm_like', 'camel_case_like', 'ignore_case', 'last_upper']})<cr>

e foo.txt
call feedkeys( "1Ga\<s-space>", "m")
