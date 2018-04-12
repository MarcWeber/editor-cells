
function! cells#debug#Log(s)
  let s = type(a:s) == type('') ? a:s : string(a:s) 
  call writefile([s], '/tmp/editor-cells-log-vim-' . $USER, 'append')
endf

