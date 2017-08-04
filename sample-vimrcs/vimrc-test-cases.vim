set nocompatible
filetype indent plugin on | syn on

let s:path = expand('<sfile>:p:h:h')

exec 'set rtp+='.fnameescape(s:path)
call cells#Load()
exec 'source '.s:path.'/tests.vim'
call Test_All()
