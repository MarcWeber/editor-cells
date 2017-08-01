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
call cells#viml#EditorCoreInterface()
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
call cells#viml#Cell({'traits': ['cells#viml#logging#Trait']})
call cells#viml#Cell({'traits': ['cells#viml#ftdetect#Trait', 'cells#viml#mappings#Trait', 'cells#viml#signs#Trait', 'cells#viml#quickfix#Trait']})
let cell_completion = cells#viml#Cell({'traits': ['cells#viml#completions#Trait']})
let cell_completion.limit = 10

" , 'cells#vim8#choice#Trait', 'cells#vim8#emit_to_one#Trait', 

fun! CompleteMonths(findstart, base)
  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
    while start > 0 && line[start - 1] =~ '\a'
      let start -= 1
    endwhile
    return start
  else
    " find months matching with "a:base"
    let res = []
    for m in split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec")
      if m =~ '^' . a:base
        call add(res, {'word': m})
      endif
    endfor
    return res
  endif
endfun

fun! SetupVimTestCells()
  call append('$', ['','','',''])

  let traits = [
        \ 'cells#examples#TraitTestMappings',
        \ 'cells#examples#TraitTestSigns',
        \ 'cells#examples#TraitTestQuickfix',
        \ 'cells#examples#TraitTestCompletionThisBuffer',
        \ 'cells#examples#TraitTestCompletionAllBuffers',
        \ 'cells#examples#TraitCompletionLastInsertedTexts',
        \ 'cells#examples#TraitCompletionLocalVars',
        \ ]
  for t in traits
    call cells#viml#Cell({'traits': [t]})
  endfor

  call cells#viml#Cell({'traits': ['cells#examples#TraitCompletionFromCompletionFunction'], 'omnifuns': ['CompleteMonths'] })

  sp | enew
  call append('$', [
        \ 'there should be one sign at buffer 1',
        \ 'quickfix list should have one line with text ',
        \ ])
  noremap <F10> :qa!<cr>
endf


let s:this_dir = expand('<sfile>:p:h')

" fun! SetupPy2TestCells()

"   " provide list of filenames for CompletionBasedOnFiles
"   let c = cells#viml#Cell({})
"   fun! c.l_project_files(event)
"     call self.reply_now(a:event, cells#util#Flatten1(map([s:this_dir.'/**/*.vim', s:this_dir.'/**/*.py', s:this_dir.'/README.md'], 'split(glob(v:val), "\n")')))
"   endf

" if has('python')
" py << END
" import cells.examples
" # cells.examples.Completion() # works (except camel case like matching
" cells.examples.Mappings() # TODO
" cells.examples.Signs()    # TODO
" cells.examples.Quickfix() # TODO
" cells.examples.CompletionBasedOnFiles() # TODO
" END
" endif
" endf


fun! SetupPy3TestCellsExternalProcess()
  " provide list of filenames for CompletionBasedOnFiles
  let c = cells#viml#Cell({})
  fun! c.l_project_files(event)
    call self.reply_now(a:event, cells#util#Flatten1(map([s:this_dir.'/**/*.vim', s:this_dir.'/**/*.py', s:this_dir.'/README.md'], 'split(glob(v:val), "\n")')))
  endf

  let py3_cell_collection_cell = cells#viml#Cell({'traits': ['cells#vim8#CellCollectionExternalProcessTrait'], 'cmd': ['python', s:this_dir.'/py3cellcollection.py'] })
  " call py3_cell_collection_cell.send_json({'new-cell-instance': 'cells.examples.Mappings'})
  " call py3_cell_collection_cell.send_json({'new-cell-instance': 'cells.examples.Signs'})
  " call py3_cell_collection_cell.send_json({'new-cell-instance': 'cells.examples.Quickfix'})
  " call py3_cell_collection_cell.send_json({'new-cell-instance': 'cells.examples.CompletionBasedOnFiles'})
endf

" echom 'use the following examples call SetupVimTestCells | call SetupVimTestCells()'

if cells#vim_dev#GotoError('first') | cfirst | endif
nnoremap <esc>. :cnext<cr>

command First call cells#vim_dev#GotoError('first')
