if !exists('g:cells') | let g:cells = {} | endif |let s:c = g:cells
let s:c.cells_examples_vim_dev = get(s:c, 'cells_examples_vim_dev', {})
let s:c =  s:c.cells_examples_vim_dev


fun! cells#vim_dev#LoadScript(filename) abort
  let expanded = expand(a:filename)
  let s:c.scripts = get(s:c, 'scripts', {})
  if (file_readable(expanded))
    let s:c.scripts[a:filename] = {'expanded': expanded, 'lines':readfile(expanded)}
  endif
endf

fun! cells#vim_dev#UpdateScripts() abort
  " usage:  :call setqflist(cells#vim_dev#UpdateScripts('SetupVimTestCells[4]..cells#viml#Cell[44]..cells#TraitTestQuickfix[4]..13[4]..cells#viml#emit_selector[1]..cells#viml#emit[5]..9[7]..cells#viml#emit_selector[1]..cells#viml#emit[5]..70[1]..88[17]..90[6]..71'))
  let scriptnames = map(cells#util#OutputAsList('scriptnames'), 'matchstr(v:val, " *\\d\\+: \\zs.*")')
  call map(scriptnames, 'cells#vim_dev#LoadScript(v:val)')
endf

fun! cells#vim_dev#FindSourceForDynFun(nr, opts) abort
  let opts = a:0 > 0 ? a:1 : {}
  if get(opts, 'UpdateScripts', 1)
    call cells#vim_dev#UpdateScripts()
  endif

  " 3[9] like function
  let fun_lines = cells#util#OutputAsList('function{'.a:nr.'}')
  if join(fun_lines, "\n") =~ 'E123'
    echom 'fun '.a:nr.' unkown ?'
    return []
  endif
  let fun_lines_stripped = map(fun_lines[2:-2], 'v:val[3:]')
  if len(fun_lines_stripped) == 0
    echoe 'len fun_lines_stripped == 0 on '.string(fun_lines)
  endif
  let args = matchstr(fun_lines[1], '\zs([^)]*)\ze')
  let matched = 0
  for [f, script_] in items(s:c.scripts)
    if len(fun_lines_stripped) +1 < len(script_.lines)
      for c_idx in range(0, len(script_.lines) - len(fun_lines_stripped)-1)
        if  script_.lines[c_idx] !~ args | continue | endif
        let match = 1
        for f_idx in range(0, len(fun_lines_stripped)-1)
          if fun_lines_stripped[f_idx] !~ '^\s*$' && fun_lines_stripped[f_idx] != script_.lines[f_idx+c_idx+1]
            let match = 0
            break
          endif
        endfor
        if match
          let matched = 1
          return [script_.expanded, c_idx]
          break
        endif
      endfor
    endif
    if matched | break | endif
  endfor
  return []
endf

fun! cells#vim_dev#VimTraceToQFList(trace) abort
  call cells#vim_dev#UpdateScripts()
  let things = split(a:trace, '\.\.')
  let qflist = []
  for thing in things
    let matched = 0
    let x = split(thing, '[\[\]]')
    if x[0] =~ '\d'

      let pos = cells#vim_dev#FindSourceForDynFun(x[0], {'UpdateScripts': 0})
      if len(pos) > 0
        call add(qflist, {'filename' : pos[0], 'lnum': pos[1]+get(x, 1, 0)+1})
        let matched = 1
      else
        echom "not found ".thing
      endif
    elseif file_readable(expand(thing))
      call add(qflist, {'filename' : expand(thing), 'lnum': 0})
      let matched = 1
    else
      " foo#bar#Baz like function
      let matched = 0
      for [f, script_] in items(s:c.scripts)
        for c_idx in range(0, len(script_.lines)-1)
          if script_.lines[c_idx] =~ 'fun.*\s'.x[0].'('
            call add(qflist, {'filename' : script_.expanded , 'lnum': c_idx+get(x, 1, 0)+1})
            " echom 'thing '.thing.' found at '.string({'filename' : script_.expanded , 'lnum': c_idx+get(x, 1, 0)+1})
            let matched = 1
          endif
          if matched | break | endif
        endfor
      endfor
    endif
  endfor
  return qflist
endf

fun! cells#vim_dev#VimTraceToRemote(servername, trace) abort
  call remote_expr(a:servername, 'call setqflist('.string(cells#vim_dev#VimTraceToQFList(a:trace)).')')
endf

fun! cells#vim_dev#ErrorToQuickFix(lines) abort
  let qflist = []

  " Error detected while processing function cells#tests#RunAllTests[1]..cells#tests#RunTests[9]..6[1]..22[1]..16[14]..1[3]..cells#viml#emit
  " _selector[1]..cells#viml#emit[13]..19[2]..10:
  let qflist = cells#vim_dev#VimTraceToQFList(split(a:lines[0][:-2], ' ')[-1])

  if len(qflist) > 0 && len(a:lines) > 1 && a:lines[1] =~ '^line[ \t]*\d'
    let qflist[-1]['lnum'] += matchstr(a:lines[1], '\zs\d\+\ze')
  endif

  let qflist = reverse(qflist)
  let rest_lines = a:lines[2:]
  if len(rest_lines) > 0 && rest_lines[0] =~ '^Traceback'
    let py_qflines = []
    " python trace lines
    let i = 0
    for i in range(1, len(rest_lines)-1)
      let matches = matchlist(rest_lines[i], ' File "\([^"]*\)", line \([^,]*\), in \(.*\)')
      if len(matches) > 1
        call add(py_qflines, {'filename' : matches[1] , 'lnum': matches[2], 'text': matches[3]})
      elseif rest_lines[i] =~ '^\S'
        " First line without indent seems to be the 'error' description in
        " Python
        call add(py_qflines, {'text' : rest_lines[i]})
        " end of Python line
        break
      else
        let py_qflines[-1]['text'] = rest_lines[i]
      endif
    endfor
    let qflist =  qflist[0:0] + py_qflines + map(a:lines[3:5], '{"text":v:val}') + qflist[1:]
  else
    let qflist[0]['text'] = a:lines[2]
    let qflist =  qflist[0:0] + map(a:lines[3:5], '{"text":v:val}') + qflist[1:]
  endif

  call setqflist(qflist)
  cope
endf

fun! cells#vim_dev#GotoError(which) abort
  let messages = cells#util#OutputAsList('messages')
  for m in a:which == 'first' ?  range(0, len(messages)-1) : reverse(range(0, len(messages)-1))
    if messages[m] =~ 'Error detected while processing function'
      call cells#vim_dev#ErrorToQuickFix(messages[m:m+100])
      return 1
    endif
  endfor
endf

fun! cells#vim_dev#Trace() abort
  try
    throw "oops"
  catch /.*/
    return matchstr(v:throwpoint, 'function \zs.*\ze\.\.[^.]*, line.*$')
  endtry
endf
