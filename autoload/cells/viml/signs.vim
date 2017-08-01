if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells
let s:c['next_sign_id'] = get(s:c, 'next_id', 54674)

fun! cells#viml#signs#Trait(cell) abort

  call cells#traits#Ask(a:cell)

  " if cells they mappings changed reassign
  fun! a:cell.l_signs_changed(event) abort
    let ask = []
    for bufnr in range(1, bufnr('$'))
      " reset all signs - brute force - could be optimized
      if !bufexists(bufnr) || !bufwinnr(bufnr) | continue | endif
      call add(ask, cells#viml#signs#BufData(bufnr))
    endfor

    " if asking for all and refreshing all a good idea? signs move with
    " content. If one source changes, probably only that should be updated.
    " See quickfix_list implemenation below
    call self.update_buffers(ask)
  endf
  fun! a:cell.update_buffers(bufnrs)
    call self.ask('update_signs', {'type': 'signs', 'limit': self.limit, 'for_buffers': a:bufnrs})
  endf

  fun! a:cell.update_signs(request)
    call cells#viml#signs#UpdateSigns(a:request.event, a:request.results_good)
  endf

  fun! a:cell.l_bufnew(event)
    call self.update_buffers([cells#viml#signs#BufData(a:event.bufnr)])
  endf
endf

fun! cells#viml#signs#SignsUpdateBuffer(signs) abort
  " signs: {'category': , 'name': .. 'signs': [..] }

  let placed_signs = cells#util#ByKeysDefault(getbufvar(a:signs.bufnr, ""), ['cells_placed_signs', a:signs.category, a:signs.name], {})
  let new_ = {}
  for s in a:signs.signs
    let new_[s.line] = get(new_, s.line, {'sign_id': 0, 'signs': []})
    call add(new_[s.line]['signs'], s)
  endfor

  for k in keys(new_)
    if !has_key(placed_signs, k)
      let next_ = s:c.next_sign_id
      let s:c.next_sign_id += 1
      exec 'sign place ' . next_ . " line=" . k . " name=".a:signs.name." buffer=".a:signs.bufnr
      let new_[k].sign_id = next_
      let placed_signs[k] = new_[k]
    endif
  endfor

  for k in keys(placed_signs)
    if !has_key(new_, k)
      exec 'sign unplace '. placed_signs[k].sign_id
      call remove(placed_signs, k)
    endif
  endfor
endf

fun! cells#viml#signs#UpdateSigns(event, results) abort
  let results = cells#util#Flatten1(a:results)
  for data in a:event.for_buffers
    let bufnr = data.bufnr
    if type(getbufvar(bufnr, "&")) == type('') | echom 'got signs for not existing buffer '.bufnr | continue | endif 
    let placed_signs = cells#util#ByKeysDefault(getbufvar(bufnr, "&"), ['cells_placed_signs'], {})
    let results_by_bufnr = filter(copy(results), 'v:val.bufnr == '.bufnr )

    " update to sign (category,name) tuples which have been used previously
    for category in keys(placed_signs)
      for name in keys(placed_signs[category])
        let results_by_category_name = filter(copy(results_by_bufnr), 'v:val.category = '.string(category).' & v:val.name = '.string(name))
        " rest, filter in place
        call  filter(results_by_bufnr, '!(v:val.category = '.string(category).' & v:val.name = '.string(name).')')
        if len(results_by_category_name) > 1
          let signs = cells#util#Flatten1(map(copy(results_by_category_name), 'v:val.signs'))
          call cells#viml#signs#SignsUpdateBuffer({'bufnr': bufnr, 'name': name, 'category': category, 'signs': signs})
        else
          call cells#viml#signs#SignsUpdateBuffer({'bufnr': bufnr, 'name': name, 'category': category, 'signs': []})
        endif
      endfor
    endfor

    " add signs which haven't been used before
    for [category, name] in map(cells#util#Union([map(copy(results_by_bufnr), 'v:val.category . "|||" . v:val.name')]), 'split(v:val, "|||")')
      let results_by_category_name = filter(copy(results_by_bufnr), 'v:val.category == '.string(category).' && v:val.name == '.string(name))

      " assuming all definitions are the same
      silent! exec 'sign define '.name.' '.results_by_category_name[0].definition

      let signs = cells#util#Flatten1(map(copy(results_by_category_name), 'v:val.signs'))
      call cells#viml#signs#SignsUpdateBuffer({'bufnr': bufnr, 'name': name, 'category': category, 'signs': signs})
    endfor

  endfor
endf

fun! cells#viml#signs#BufData(bufnr) abort
  return {'bufnr': a:bufnr, 'fullpath': expand('%'.a:bufnr.':p'), 'name': bufname(a:bufnr)}
endf
