if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells

fun! cells#vim8#mappings#Trait(cell) abort

  let a:cell.mappings_by_sender = get(a:cell, 'mappings_by_sender', {})
  let a:cell.active_mappings_by_scope = get(a:cell, 'active_mappings_by_scope', {})

  call cells#traits#Ask(a:cell)

  fun! a:cell.l_mappings_changed(event) abort
    call self.ask({'event': {'type': 'mappings'}, 'cb': 'mappings_received', 'selector': {'id': a:event.sender}})
  endf

  fun! a:cell.mappings_received(request) abort
    for e in a:request.results
      if has_key(e, 'result')
        let self.mappings_by_sender[e.sender] = e.result
      endif
    endfor
    call self.update_mappings(['global', 'commandline', 'bufnr:'.bufnr('%')] )
  endf

  fun! a:cell.l_killed(event) abort
    call remove(self.mappings_by_sender, a:event.sender)
    call self.update_mappings(['global', 'commandline', 'bufnr:'.bufnr('%')] )
  endf

  fun! a:cell.l_bufenter(event) abort
    call self.update_mappings(['bufnr:'.a:event.bufnr])
    " [{scopes: scopes, mappings:  [{'lhs', 'emit_event': {}}] ]
  endf

  " fun! a:cell.hash(s)
  "   let sum = 234
  "   for i in range(0, len(a:s)-1)
  "     let sum = ((sum + char2nr(a:s[i]) * i) - i) / 2
  "   endfor
  " endf


  fun! a:cell.mappings_matching(mode, scope) abort
    if a:scope =~ '^\%(global\|commandline\)'
      let matchexpr = 'v:val.scope == a:scope && a:mode =~ v:val.mode'
    elseif a:scope =~ '^bufnr:'
      let fr = len("filetype_regex:")
      let fn = len("filename_regex:")
      let bufnr = split(a:scope, ':')[1]
      let filetype = getbufvar(bufnr * 1, '&filetype')
      let filename = bufname(bufnr * 1)
      let matchexpr = '(v:val.scope == a:scope || (v:val.scope[:'.(fr-1).'] == "filetype_regex:" && filetype =~ v:val.scope['.fr.':])|| (v:val.scope[:'.(fn-1).'] == "filename_regex:" && filename =~ v:val.scope['.fn.':])) && a:mode =~ v:val.mode'
    else
      throw 'unkown scope '.a:scope
    endif
    return filter(cells#util#Flatten1(values(self.mappings_by_sender)), matchexpr)
  endf

  fun! a:cell.update_mappings(scopes) abort
    for mode in ['visual', 'normal', 'insert', 'select']
      for scope in a:scopes
        let to_be_mapped = self.mappings_matching(mode, scope)
        let active_lhs = cells#util#ByKeysDefault(self.active_mappings_by_scope, [mode.'|'.scope], {})
        call self.update(active_lhs, to_be_mapped, scope, mode)
      endfor
    endfor
  endf

  fun! a:cell.update(active_lhs, to_be_mapped, scope, mode) abort

    let list = matchlist(a:scope, '^\(bufnr\):\(.*\)')
    if len(list) >= 2
      let current_buffer = bufnr('%')
      let prefix = ''
      if (current_buffer != list[2]) | echoe 'different bufnr - slow mapping '.current_buffer.' '.list[2] | let prefix = 'b '.list[2].' | ' | endif
      let map_cmd   = prefix.'map <buffer>'
      let unmap_cmd = prefix.'unmap <buffer>'
    else
      let p = {'global': '', 'commandline' : 'c'}
      let map_cmd = p[a:scope].a:mode[0].'map '
      let unmap_cmd = p[a:scope].a:mode[0].'unmap '
    endif


    let used_lhs = {}
    " remove
    for m in a:to_be_mapped
      let used_lhs[m.lhs] = 1
      if !has_key(a:active_lhs, m.lhs)
        " setup mapping
        let a:active_lhs[m.lhs] = 1
        let event = {'type': 'evoke_mapping', 'scope': a:scope, 'mode': a:mode, 'lhs' : m.lhs}
        if a:mode == 'insert'
          let rhs   = '=cells#Emit('.string(event).', '.string({'id': self.id}).')'
          "let rhs=substitute(rhs, '<', '<lt>', 'g')
          "let rhs=substitute(rhs, ' ', '<space>', 'g')
          let rhs = '<c-r>'.rhs.'<cr>'
        else
          let rhs   = ' :call cells#Emit('.string(event).', '.string({'id': self.id}).')<cr>'
          let rhs=substitute(rhs, ' ', '<space>', 'g')
          let rhs=substitute(rhs, '<', '<lt>', 'g')
        endif
        echom 'mapping '.map_cmd.' '.m.lhs.' '.rhs
        exec map_cmd.' '.m.lhs.' '.rhs
      endif
    endfor

    for o in keys(a:active_lhs)
      if !has_key(used_lhs, o)
        call remove(a:active_lhs, k)
        exec unmap_cmd.' '.o
      endif
    endfor

    if exists('current_buffer') && current_buffer != bufnr('%')
      exec 'b '.current_buffer
    endif
  endf

  fun! a:cell.l_evoke_mapping(event) abort
    let all = filter(copy(self.mappings_matching(a:event.mode, a:event.scope)), 'tolower(v:val.lhs) == '.string(tolower(a:event.lhs)))

    if len(all) == 1
      let mapping = all[0]
      if has_key(mapping, 'emit_event')
        call cells#Emit(mapping.emit_event)
      elseif has_key(mapping, 'rhs')
        call feedkeys(mapping.rhs, 't')
      else
        echoe "don't know how to run evoke mapping ".string(a:mapping)
      endif
    else
      echoe 'no ore multiple mappings found for '.string(a:event).' found: '.string(all)
      " let user choose one ... TODO, then evoke
    endif
  endf

  return a:cell
endf
