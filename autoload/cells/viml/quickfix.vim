" vim8 implementation of most features
if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells

fun! cells#viml#quickfix#Trait(cell) abort

  let a:cell.limit = get(a:cell, 'limit', 1000)

  fun! a:cell.l_quickfix_list_available(event)
    call self.ask('handle_qf_reply', {'type': "quickfix_list", 'sender': self.id, 'limit': self.limit+1, 'selector': {'id': a:event.sender}})
  endf

  fun! a:cell.handle_qf_reply(request)
    let result = a:request.results_good[0]
    if has_key(result, 'list')
      call setqflist(result.list[:self.limit-2])
      if has_key(self, 'limit') && len(result.list) == self.limit +1
        let result.list = result.list[:self.limit-2]
        echom 'qflist has been truncated for speed reasons'
      else
      endif
      call setqflist(result.list)
      let has_errors = 0
      let has_warnings = 0
      for x in result.list
        if x.type == 'E' | let has_errors = 1 | endif
        if x.type == 'W' | let has_warnings = 1 | endif
      endfor
      if has_warnings
        cclose
        echom 'quickfix available with warnings, use :cope to show'
      else
        cope
      endif
    elseif has_key(result, 'cfile')
      exec 'set efm='. result.errorformat
      exec 'cfile '.fnameescape(result.cfile)
    endif
  endf

  call cells#traits#Ask(a:cell)

  return a:cell
endf
