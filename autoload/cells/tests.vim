" test viml implementation

fun! cells#tests#RunAllTests() abort
  let tests = []
  call add(tests, 'cells#tests#TestAskReply')
  call add(tests, 'cells#tests#SelectorByIdVim')
  let tests = []
  call add(tests, 'cells#tests#TestAskReplyVimAskingPy')
  " call add(tests, 'cells#tests#TestAskReplyPyAskingVim')
  call cells#tests#RunTests(tests)
endf

fun cells#tests#RunTests(list) abort
  " simple tests
  let v:errors = []

  let tests = []
  for t in a:list
    echom ' == RUNNING TEST == '.t
    let v:errors = []
    let test = call(t, [])
    if has_key(test, 'up') | call test.up() |endif
    call test.run()
    if has_key(test, 'down') | call test.down() |endif

    for [k,v] in items(test.cases)
      if !v
        echoe 'test '.t.'->'.k.' failed'
      endif
    endfor
    if len(v:errors) > 0
      echoe v:errors
    endif
  endfor
endf

fun! cells#tests#TestAskReply() abort

  let test = {}

  fun! test.up() abort

    let cell = cells#viml#Cell({}) " this will already register the cell globally

    call cells#traits#Ask(cell)

    let self.cell = cell
    let self.cases = {}

    " listen to event_name
    fun! cell.l_listen1(event) abort
      " reply immediately
      call self.reply_now(a:event, 'listen1')
    endf

    fun! cell.l_listen2(event) abort
      " reply by event (asyncchronously)
      call add(a:event.wait_for, self.id)
      let self.listen2_event = a:event
    endf
    fun! cell._listen2_reply()
      call self.async_reply(self.listen2_event, 'listen2')
    endf

    fun! cell.ask_all() abort
      call self.ask('result_listen1', {'type': 'listen1'})
      call self.ask('result_listen2', {'type': 'listen2'})
      call self._listen2_reply()
    endf

    fun! cell.result_listen1(request) abort
      let self.listen1_results = a:request.results_good
    endf

    fun! cell.result_listen2(request) abort
      let self.listen2_results = a:request.results_good
    endf

  endf

  fun! test.run() abort
    call self.cell.ask_all()
    let self.cases['listen1'] = self.cell.listen1_results == ['listen1']
    let self.cases['listen2'] = self.cell.listen2_results == ['listen2']
  endf

  fun! test.down() abort
    call self.cell.kill()
  endf

  return test
endf

fun! cells#tests#SelectorByIdVim() abort
  let test = {}
  let test.cases = {}

  fun! test.run()
    let cell1 = cells#viml#Cell({})
    let cell2 = cells#viml#Cell({})

    for cell in [cell1, cell2]
      fun! cell.l_event(event)
        let self.event = a:event
      endf
    endfor

    call g:cells.emit({'type': 'event', 'selector' : {'id': cell1.id }})

    let self.cases['1_hit']     =  has_key(cell1, 'event')
    let self.cases['2_not_hit'] = !has_key(cell2, 'event')

    for cell in [cell1, cell2] | call cell.kill() | endfor
  endf

  return test
endf


fun! cells#tests#TestAskReplyVimAskingPy() abort

  let test = {}
  let test.cases = {}

  fun! test.up() abort

py << EOF

class MyCell(cells.py.Cell):

  def l_pylisten1(self, event):
    self.reply_now(event, 'pylisten1')

  def l_pylisten2(self, event):
    event['wait_for'].append(self.id)
    self.pylisten2_event = event

  def _listen2_reply(self):
    self.async_reply(self.pylisten2_event, 'pylisten2')

mycell = MyCell()
EOF
  endf

  fun! test.run() abort

    let cell = cells#viml#Cell({})
    echom 'test cell id' . cell.id
    call cells#traits#Ask(cell)

    fun! cell.result_pylisten1(request) abort
      let self.pylisten1_results = a:request.results_good
    endf

    fun! cell.result_pylisten2(request) abort
      let self.pylisten2_results = a:request.results_good
    endf

    call cell.ask('result_pylisten1', {'type': 'pylisten1'})
    call cell.ask('result_pylisten2', {'type': 'pylisten2'})
    py mycell._listen2_reply()

    let self.cases['pylisten1'] = cell.pylisten1_results == ['pylisten1']
    let self.cases['pylisten2'] = cell.pylisten2_results == ['pylisten2']

    call cell.kill()
    py mycell.kill()
  endf

  return test
endf

fun! cells#tests#TestAskReplyPyAskingVim() abort

  let test = {}

  fun! test.run() abort

    let cell = cells#viml#Cell({}) " this will already register the cell globally

    call cells#traits#Ask(cell)

    let self.cell = cell
    let self.cases = {}

    " listen to event_name
    fun! cell.l_listen1(event) abort
      " reply immediately
      call self.reply_now(a:event, 'listen1')
    endf

    fun! cell.l_listen2(event) abort
      " reply by event (asyncchronously)
      call add(a:event.wait_for, self.id)
      let self.listen2_event = a:event
    endf
    fun! cell._listen2_reply()
      call self.async_reply(self.listen2_event, 'listen2')
    endf

py << EOF

class MyCell(cells.py.Cell):

  def ask_all(self):
      call self.ask('result_listen10', {'type': 'listen10'})
      call self.ask('result_listen20', {'type': 'listen20'})
      call self._listen2_reply()

  def result_listen10(self, request):
      self.listen10_results = request['results_good']

  def result_listen20(self, request):
      self.listen20_results = request['results_good']


mycell = MyCell()

mycell.ask_all()
vim.eval('cell._listen2_reply()')

# TEST
cells.util.to_vim( 1 if mycell.listen10_results == ['listen10'] else 0)
vim.eval('self.cases["listen10"] = g:to_vim')

cells.util.to_vim(1 if mycell.listen20_results == ['listen20'] else 0)
vim.eval('self.cases["listen20"] = %s')

mycell.kill()

EOF
    call cell.kill()

  endf

  return test

endf
