editor-cell - Ending part of the editor war ?
=============================================
Editors supported: 
  Vim (done),
  Emacs (coming),
  ...

Features supported:
  * completions (done), todo: eclim, ycmd, server-protocol
  * goto to definition of thing at cursor (coming)
  * templates (coming)
  * signs
  * error lists
  * write using the language you know best (VimL/Python/..)
  * watch logfiles for errors and load them (watch_cmd_erros) as from webpack --watch, or any similar tool
  * to be tried:
    Fit enough to implement client/server (browser) based support / no idea
    about how fast it would be.

Combine reusable cells the way you want

![list of cells](https://github.com/MarcWeber/editor-cells/blob/master/Cells.md)

ROADMAP / TODO
==============

[ ] pattern support
  ["fooo", "bar" .. pattern is ", "
  TS: "abc" | "xoo"  pattern is " | " ..
  why having to type it ?

[ ] string completion support. If you use "boo" multiple times it's highly likely that you use "boo" again.
    Thus sort strings by distance & count ?

SHOTS / Videos
==============
This gif animation shows python based completion taking distance to cursor into account.
The code triggering the completion is writen in VimL.

![alt text](https://github.com/MarcWeber/editor-cells/raw/master/images/py-sample-completion-external-process-with-auto-completion.gif "Demo Gif Animation 1")

You can write your own completions easily such as cells#examples#TraitCompletionContext.
This sample code finds function arguments and local vars triggering completions for them.

Configuration examples
===========
Vim: section below


EMACS example
=============
To be written
```elisp
; TODO
```

WHAT IS A CELL?
===================
A cell has
  - has an id such as 'viml:20'
  - At least one purpose such as "I provide signs / completions / mappings"
  - can talk to other cells by receiving and sending events
Some porcelain is be provided for making async conversations easier


How do events look like ?
=========================
An event is a dictionary which can be serialized (such as JSON) because most
languages understand it in some way. 
For now values should not contain 0 bytes (VimL restriction ?) - if its very
important we have to find a solution.

Event dictionary keys:

  type: All events have it, e.g. 'completions' asking for completions

  reply_to: <cell_id> If cells should sent back a reply emit an event to this.
            Use one of the following reply types:
            {'error': string}
            {'value': string}
            {'wait_for': [<list of cell ids>]}

            maybe partial results will be supported in the future - streaming
            as in JsonRpc - so that completion can send 1000 completions piecewise

  request_id:  Only makes sens if reply_to is used. When replying pass the same
               id so that asking cell knows which question the reply belongs to

  timeout_sec: optional/ unimplemented: If you know that you don't want to wait forever set a time limit here.

  sender: <cell-id>: Giving hints about the origin of an event

  wait_for: [] list of cell_ids to be wait for till the result is complete (async replies)
  wait_for_id: Eeach reply must contain this key to tell the asking cell that this reply was received so that it knows when all replies have arrived
  result/error: reply result or reply exception
  results:  [] list you can add results to (immediate replies). The result should have the form {'result/error': .., [...]}
  wait_for_id__for_requesting_cell: When passing an event to another collection which replies asynchronously, see bin/py3cellcollection.py

CELL COLLECTIONS
================
Each language has its own set of cells and some cells taking care
of passing communication between them - its your task to setup communication in
a way which works depending on how you want to use editor-cells.

See "EVENTS Python" section below about 3 ways about how 'cell collection' interfacing
can be implemented

Get a list of all cells from all cell collections:
  let cer = cells#viml#CellEchoReply()
  call g:cells.emit({'reply_to': cer.id, 'type': 'cell_list'})

Example external process see py3cellcollection.py, mind the special event
set-cell-collection-name to set the collection name

VIM SAMPLE CONFIGURATION
=======================================
```viml
  set rtp+=path-to-editor-cells

  call cells#viml#CellCollection()
  " Editor core events implementation
  call cells#viml#EditorCoreInterface()
  call cells#viml#EditorVimInterface()
  call cells#ProvideAPI()


  " ask multiple completion strategies to provide their completions:
  let viml_cells_to_be_created = {
        \ 'TestCompletionThisBuffer': ['cells#examples#TraitTestCompletionThisBuffer',  {}],
        \ 'TestCompletionAllBuffers': ['cells#examples#TraitTestCompletionAllBuffers',  {}],
        \ 'CompletionLastInsertedTexts': ['cells#examples#TraitCompletionLastInsertedTexts',  {}],
        \ 'CompletionLocalVars': ['cells#examples#TraitCompletionContext',  {}],
        \ 'DefinitionsAndUsages': ['cells#examples#TraitDefinitionsAndUsages',  {}],
        \ }

  " goto definition of thing at cursor
  nnoremap gd :call g:cells.cells['DefinitionsAndUsages'].definitions()<cr>
  " goto usages of thing at cursor
  nnoremap gu :call g:cells.cells['DefinitionsAndUsages'].usages()<cr>
  " find out about type below cursor
  nnoremap gu :call g:cells.cells['DefinitionsAndUsages'].usages()<cr>

  " A trait just adds some methods to a dictionary - this way you could reload
  " or update the implementation on buf write later by rerunning the trait
  " function on the cell.

  " What do the completion providers do ?
  " TraitTestCompletionThisBuffer => complete words of current buffer
  " TraitTestCompletionAllBuffers => complete words in all opened buffers
  " TraitCompletionLastInsertedTexts': {} => complete words from last texts you typed in this session
  " TraitCompletionContext': {},        =>  When using var foo = 7; ist very likely that you'll be using foo, so rate those hits higher

  " For each completion create a cell having the trait
  for [id, v] in items(viml_cells_to_be_created)
    call cells#viml#Cell({'id': id,  'traits': [t[0]]})
  endfor

  " Note for viml devs: A special trait cells#traits#Ask(cell) adds porcelain
  " for ask - replies communication

  " Now create a cell which can ask the implementations and shows the popup
  let cell_completion = cells#viml#Cell({'traits': ['cells#viml#completions#Trait']})
  let cell_completion.limit = 10

  " Now create a cell which takes care about automatically showing the
  " completion depending on cursor position/ language
  " only using LocalVars completion because its fast and very likely to cause matches
  let by_filetype = []
  call add(by_filetype, {
    \ 'filetype_pattern' : '.*',
    \ 'when_regex_matches_current_line': '[a-z]|',
    \ 'completing_cells': [traits['cells#examples#TraitCompletionContext'].id]
    \ })

  " The | means cursor location. Thus if you've typed one lower case char
  " completion will kick in

  " trigger completions automatically
  call cells#viml#Cell({'traits': ['cells#viml#completions#TraitAutoTrigger'], 'by_filetype':  [], 'id': 'CompletionAutoTrigger', 'trigger_wait_ms': 75})

  " use fast buffer based and local var based completions always after one char has been typed
  call add(g:cells.cells['CompletionAutoTrigger'].by_filetype, {
    \ 'filetype_pattern' : '.*$',
    \ 'when_regex_matches_current_line': '\<\w|',
    \ 'completing_cells': ['CompletionLocalVars', 'CompletionThisBuffer']
    \ })


  " setup python network running within Vim requiruing Python3
  let g:bridge_cell = cells#viml_py3_inside_vim#BridgeCell()

  " language server node ipc (tested on linux only), running on Python
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.language_server_protocol_client.LanguageServerProtocolClient', 'args': [], 'kwargs': {'node_ipc': v:true, 'cmd': ['/run/current-system/sw/bin/node', '/pr/tasks/language-server/vscode-intelephense/client/server/server.js'], 'id': 'PHPCompletion'}})

  " Use Python's jedi completion only after . and after one char has been typed
  call add(g:cells.cells['CompletionAutoTrigger'].by_filetype, {
    \ 'filepath_regex' : '\.py$',
    \ 'when_regex_matches_current_line': '\w\+|\|\.|',
    \ 'completing_cells': ['JediCompletion']
    \ })

  " As alternative map <s-space> to kick of completion provide by cell ids id1,
  " id2, or avoid completing_cells_selector to use all completion providers
  " a completion id depends on your cells setup. See CompletionLastInsertedTexts as example.
  " ids is optional
  inoremap <s-space> <c-r>=call g:cells.emit({'type': 'complete', 'position': getpos('.'), 'limit': 20, 
    \ 'match_types' : ['prefix', 'ycm_like', 'camel_case_like', 'ignore_case', 'last_upper'],
    \ 'completing_cells_selector' : {'ids': [id1, id2]},
    \ 'completeopt' : 'menu,menuone,preview'
    \ })<cr>

  " See sample-vimrcs/* about how to integrate python cells

  " Example eclim completion wrappers:
  let eclim_completions = {}
  let eclim_completions['eclim_java'] = ['\.java$', 'eclim#java#complete#CodeComplete']
  let eclim_completions['eclim_html'] = ['\.html$', 'eclim#html#complete#CodeComplete']
  let eclim_completions['eclim_xml']  = ['\.xml$', 'eclim#xml#complete#CodeComplete']
  let eclim_completions['eclim_js']   = ['\.js$', 'eclim#javascript#complete#CodeComplete']
  let eclim_completions['eclim_css']  = ['\.css$', 'eclim#css#complete#CodeComplete']
  let eclim_completions['eclim_php']  = ['\.php$', 'eclim#php#complete#CodeComplete'] " does not take care of Eclims goto PHP definiton yet
  for [k,v] in items(eclim_completions)
    call cells#viml#Cell({'traits': ['cells#examples#TraitCompletionFromCompletionFunction'], 'id': k, 'completion-functions': [{'filepath_regex': v[0], 'completion-function': v[1], 'first_char_apply_match_score': 1, 'spaces_after_cursor': 1, 'use_cache': 1}]})
  endfor

```

Viml cells implementation
=========================
Most important sample code can be found in autoload/cells/viml.vim
and some sample cell implementations can be found at autoload/cells/vim8

The VimL system is setup like this:
  call cells#viml#CellCollection()
  " Editor core events implementation
  call cells#viml#EditorCoreInterface()
  call cells#ProvideAPI()


Currently I don't know about any promise like library for VimL,
so callbacks must be chained, see first parameter to ask().

Example cell

  let cell = cells#viml#Cell({}) " this will already register the cell globally

  " listen to event_name
  fun! cell.l_<event_name>(event)
    call self.reply_now(a:event, <result>)

    " or if you want to reply later:
    call add(aevent.:wait_for, self.id) " notify that a reply will happen
    call self.async_reply(a:event, <result>) " send the reply
    call self.async_error(a:event, <error>) " send an error, because the asking cell is waiting for any reply
  endf

  " 
  fun! cell.ask_and_wait_sample()
    call self.ask({'event': {'type': '...', )}, 'cb': 'process_result'})
  endf
  fun! cell.process_result(request)
    echoe string(a:request.results_good)
  endf

  " send an event, tell everybody that a cell is new:
  call g:cells.emit({'type': 'announce_new_cell', 'cell': cell})



Viml debugging tips
===============================
  Debugging VimL See
  if cells#vim_dev#GotoError('first') | cfirst | endif
  and http://vim-wiki.mawercer.de/wiki/topic/debugging-viml.html

Python events implementation
============================
Python 3.x & asyncio (recommended)
Has asyncio which is nice for abstracting callbacks and waiting for
event replies, but is harder to setup because Python can wait for external
stuff when execution control is handed back to Vim.

See py3/* and sample-vimrcs/vimrc
py3/site-packages/cells/asyncio/examples.py

when defining listeners with def l_<NAME> .. return results by

  to reply asynchronously (signal error by throwing exception)
          await event['async_def_result'](self.id, self.__completions(event['event']))

  to reply immediately
          event['reply_now'](self.id, r)
          event['reply_error_now'](self.id, ...)

take care to call super's __init__ like to have it added to cell_collection
        super(<YOUR_CLASS_NAME>, self).__init__(*args, **kwargs)

class CompletionBasedOnFiles is a nice example illustrating about how
to start to use asnyc functions to produce a reply which itself waits for
results from events (gather). ask_iter could be used to process results as they
come in.

Python 2.x without asyncio (for completness)

  No asyncio features -> see pyinline/*
  Seems to work fine from :py and :py builtin interpreter
  see sample-vimrcs/vimrc about how to set it up
  (TODO: update l_reply and ask code to look like Vim code)

  Probably will not be mantained

Python Cells within Vim8
--------------------
* Recommended: Python 3 within Vim: sample-vimrcs/vimrc -> SetupPy3TestCellsExternalProcess()
* If you want to run ceels in many external processes see sample-vimrcs/vimrc -> SetupPy3AsyncioTestCellsWithinVim()
* discouraged: Py2 (for completness) inside Vim: sample-vimrcs/vimrc -> SetupPyInsideVimTestCells()

Python Cells within NeoVim
-----------------------
Vim8 code needs to be adopted

Python within NeoVim 8:
-----------------------
NeoVim: Should be easy to adopt the code (TODO).
There is a new option using the RPC protocol built into NeoVim

JavaScript/PHP/Java/Scala/Go/Haskell
===============================================
to be implemented

SPECIAL EVENTS / CONCEPTS / COMMON FEATURES
============================================
Quick & dirty documentation about some events already used.
Change this first, then the code, because others might follow

filename: maybe relative
fileapth: more likely to be absolute (canonical filepath)

line:   always from 1
column: atways from 1

<cursor_context>:
    "context_lines": []
    'line_split_at_cursor': [left of cursor, right of cursor]
    'position': # see getpos('.')
    'limit': 500
    'filename': ,
    'filepath': ,
    'bufid' :,
    'cword' :, word below cursor
    'offset': byte offset in file

<location_keys>:

    'filepath':

      'line': (optional)
      'col':  (optional)
    and or 
      'offset':

" internal use:

# cell core events which should be implemented by each cell collection
  { 'type': 'emit', }  emit event to all cells, also see emit_to_one
  { 'type': 'cell_collections', }   => reply {'prefix': ..., 'details': ...}
  { 'type': 'cell_collection_added'}   => reply {'name'}
  { 'type': 'cell_kill', selector: ..} # kills cells matching selector
  { 'type': 'cell_list', 'selector': ... } # reply list of ids of cells matching selector, see cells#viml#CellsBySelector
  { 'type': 'cell_new_by_name', 'name': "name", "args": [], 'network': 'viml' } # each target can implement it on its own

# cell events about cell lifetime
  { 'type': 'killed', 'sender': .. }
  { 'type': 'instance', 'options': {}, 'name': '<cell name>', } # TODO: when running external cell systems ..

# introspection: todo

{ 'type': 'set_properties', 'properties': {'enabled': v:false} } # TODO will eventually be removed
{ 'type': 'log', 'lines': [], 'prio': TODO, 'sender': optional cell_id }
{ 'type': 'killed': sender: 'cell-id' } " if other cells might depend on a cell it can notify the other cells that it has been killed

{ 'type': 'definitions', <cursor_context> } -> [{'title', 'text': 'mulitiline text', 'kind': '', <location_keys>}]
{ 'type': 'usages',      <cursor_context> } -> [{'title', 'text': 'mulitiline text', 'kind': '', <location_keys>}]
{ 'type': 'types',       <cursor_context> } -> [{'text': 'mulitiline text', 'kind': '', <location_keys>}]

{ 'type': 'error_markers_for_buf' } ->
{ 'type': 'error_markers_changed' } ->
{ 'type': 'related_files', 'type': 'close/loose' } 
  -> [{<cell_id>, 'exists': true/false, 'path': ...}]

# cell events completion
  There are some very strong contexts such as completing after 'this.' in OO
  languages which should block other completions eventually, how to implement it?
  Use all completions all the time? I don't know yet

  It also could make sense to have completions return 'context' information so
  that probabilities can be calculated about which completions to show first /
  more likely.

  Forinstance its more likely that you use a function paramteter within a
  forach(..) loop than any PHP function which is unrelated

  {'type': 'completions'
    <cursor_context>
    'cache_id': [ ... ], # if the editor still has completions in cache they don't have to be resent
    'strategy': ['all', 'match', 'first_char']
        prefix: chars have to match at the beginning
        camel_case_like ccl -> camel_case_like
        last_upper ccE -> camel_case_lik*e*
        ycm_like  -> youcompleteme like (match chars in order)
  }

  Most completions take quite a while to complete and slows down typing.
  A good strategy is what eclim does: get all completions for instance ., cache the
  result, and then filter the results depending on what was typed.

  Thus the perfect implementation sends the items once to the editor which can
  then cache and only apply on the fly filtering and narrow down as user
  continues typing. Showing more than 10 items is not that productive and also
  might slow down the editor

  reply =>
  [
    { 'cache_id':.., 'column': .., 'context': 'default', 'completions': [{'word', 'word_propability', 'description', 'continuation' : '..', 'w' => float}] }
  ]

  word: the word to be inserted

  word_propability: if you want to do probability analysis use this instead
      (for instance php has two different kinds of foreach you may want to
      differentiate in word such as for_k for_v but know how ofte its used by looking
      at word foreach instead)

  description:
  .. see completions keys

  w(eight):
    > 10 -> highly likely match
    >= 1 -> likely match
    <= 1 -> don't know, show if there is no high likely match left.

  strong_match: <reason> if set, should be shown first along with reason

  contexts: a list of words associating the word with context which can later
            be used for machine learning such as 'local var' or 'from scope'

  type

  menu: additional text which will be added after word

  kind: like kind of vim, but can have multiple chars, recommeded to keep short

  The code showing the completions might use this information for both:
  Calculating probabilities or disregarding other completions or showing them first

  <location_keys>: file, line
  <action>: action which can be run

# cell events filetype
{' 'type': 'ftdetect' }
=> reply 'js' or such
  

# cell events mappings
A cell just tells "I have mappings to be mapped" using the mappings_changed event.
modes: v(isual) n(ormal) i(insert)
Scopes:

A cell taking care of the mapping uses the 'mappings' event to ask for the mappings
If a cell is killed the cell taking care of events will be notified by the kill
event thus can unmap as neccessary

{'type': 'mappings_changed', 'sender': id}
{'type': 'mappings'}
  => 
     [{'key': 'global', 'mode':'normal', 'lhs':  '<f2>', 'emit_event': {key 'type' set: event to be emitted},
      {'key': <scope>,  'mode':<mode>, 'lhs': '<br>', 'emit_event':  {}}]

    scope: global / console / bufnr:.. / filetype_regex:.. / filename_regex=..
    mode: insert|visual|normal

  Scope expressions:
     scope == "normal"
     bufnr == 20
     filetype =~ "..."


Example implementation see autoload/cells/vim8/mappings.vim

# cell events project
  {'type': 'project_files'}
  return list of files belonging to project
  -> ['file1', 'file2']

# cell events signs
{'type': 'signs_changed', 'sender': 'cell-id'}
{'type': 'signs',  'limit': 500, 'for_buffers': [{bufnr: ..,  expanded: .. , name: ..}] }
=> [{'bufnr': bufnr, 'name': '', 'definition': 'text=-', 'catgeory': 'fooo', 'signs': [{line, comment}] ]
Example implementation see autoload/cells/vim8.vim and autoload/cells/tests.vim

# cell events quickfix
{'type': 'quickfix_list_available', 'sender': 'cell-id'}
{'type': 'quickfix_list',  'limit': 500 }
  => {'list': see :h setqflist, 'truncated': true/false}
  => {'cfile': 'file', 'errorformat' : error format to be used}
Example implementation see autoload/cells/vim8.vim and autoload/cells/tests.vim


{ 'type': 'choice', 'title': .., 'choices': [{'return': .., 'line': ..}] }

TODO:
  " {'type': 'commands', 'types': ['v', 'n', 'b', 'i']}
  " {'type': 'commands_changed', 'types': ['v', 'n', 'b', 'i']}
  templates => completion with continuation


# CORE EDITOR API which might be implemented by multiple editors
Example implementation for Vim see cells#viml#EditorCoreInterface()

{ 'type': 'editor_features' } # reply with list of features the editor implementation supports
{ 'type': 'editor_subscribe', 'subscriptions': {'name' : {}, 'name': {}} } # subscribe to features / events

{ 'type': 'editor_commands', 'commands': [command] }

  command one of
    'write_current_buffer'
    'set_current_line'
    'editor_buffers'
    'lines_of_buf_id'
    {'set_current_line': 'line_contents'}
    {'save_as_tmp': 'filename'}
    {'show_message': 'text'}
    {'eshow_rror': 'text'}

features:
  ['editor_bufopen', 'editor_bufclose', 'editor_buf_written', 'editor_buf_cursor_pos']
   {"type': 'editor_bufnew',     'bufid': <bufid>, 'filename': .., 'filepath':}
   {"type': 'editor_bufread',     'bufid': <bufid>, 'filename': .., 'filepath':}
   {"type': 'editor_bufclose',    'bufid': <bufid>, 'filename': .., 'filepath':}
   {"type': 'editor_bufwritepost', 'bufid': <bufid>, 'filename': .., 'filepath':}
   {"type': 'editor_buf_changed', 'bufid': <bufid>, 'filename': .., 'filepath':}
   {"type': 'cursor_context', 'bufid': <bufid>, 'filename': .., 'filepath':}  get current buffer info and cursor position.
   # {"type': 'buf_cursor_pos',     'bufid': <bufid>, 'filename': .., 'filepath':} TODO


CELL FEATURES (to be extendended)
====================================================
Maybe you could even call it 'interface' and knows which requests to respond to

cell features / interface (can be extended

IDEAS:
  * references of different kinds (find CSS tags matching current HTML tag/ references in code)
  * syntax checkers (no compilation)
  * open by
      a/
      b/
      foo.txt:line
      foo.txt:line:col

It can be activated/deactivated allowing you to focus on something.

A cell should one thing and do it well

Expect duplication/ redundancy, thus allow writing your own code dealing with it.
Example: If you have two cells providing a mapping <F2> to compile something then

  - you could be asked

  - you could be asked once per Vim session optionally allowing to store your
    choice in your project local or global ~/.vimrc

  - always use the "more important mapping", allowing debuggers to overwrite F5
    temporarely.

If you have 5 cells providing completion, you can activate, deactivate them or
use cell#MapJoin( filter to ony use some implementations for a mapping.


interacting with cells
====================

call cell#Notify(<opts>, [data])
  => notify all cells about something such as "I have new error lines, my mappings changed"

call cell#MapJoin(<opts>, [data], continuation)
  <opts>: 
    fun: to be called
    data: to be passed to implementations (func args)
    filter: Only ask some implementations based on this (eg cell-id regex or such)

=> call fun of all cells if they implement it, then return merged result so
that you can do something with it.

This allows to have a 

- viml implementation as fallback and provide a faster python/lua
  implementation later on.

- users to replace an implementation by their own version allowing reusability

- common interface to common features (e.g. goto definition) while allowing
  multiple backends


cells to be written
===================

cell features / interface (can be extended)

  <location_keys>: filepath, line
  <action>: action which can be run

  * error_markers
    purpose: linting / compilation result / language-server-protocol errors / ...

    cell which shows signs
    [{<cell_id>, 'style': 'style representation', 'file': 'file', 'line': '...', 'text' : 'additional attached inforamtion', 'after_text': 'text to be shown below the item', 'actions': [<action>]}]
    after_text: more details about error

  * signs_to_be_shown()
    cell which shows signs
    [{<cell_id>, 'style': 'style representation', 'file': 'file', 'line': '...', 'text' : 'additional attached inforamtion', , 'fixit': [<action>]}]

  * footer_info()
    [{<cell_id>, 'text': .. 'prio': .., 'source': ...}]


    expected result:
    [{<cell_id>, 'exists': true/false, 'path': ...}]

  * templates()

  * debug lines ?

  * actions()
    which could be turned into commands and or mappings
    [{'mode': 'normal/insert', 'action'}]

  * autocommands ?

  * provide_indentation_settings_for_file()
    purpose: figure out indentation based on your rules
    call the first time ou enter indent mode

  * syntax_checkers, for instance py2 & py3 at the same time!

IDEAS:
  * virtual content provider for things like VCS files based on url, or run executable ?
  * references of different kinds (find CSS tags matching current HTML tag/ references in code)
  * syntax checkers (no compilation)
  * open by
      a/
      b/
      foo.txt:line
      foo.txt:line:col

progress implementation

BEST PRACTISES WRITING VIML CELLS / VIML implementation
=======================================================
You can listen to events by implementing fun! cell.l_<event_type>(event) | endf

There are two ideas behind traits
  1) allow reassigning functions (thus hot updating)
  2) the typical trait case
See autoload/cells/vim8.vim

Of course the event / cell system is not most efficient. Its a trade-off
between flexibility and speed. For low level stuff hide your own code within a
cell.

Events might be serialized - thus try to limit size. Thus if you have
quickfix/sign/completion lists think about whether limiting to 1000 entries
does make sense.

CONCEPTS > MAPPINGS & SIGNS
=======================================================
See above

CONCEPTS > PROJECT (its fuzzy - is it worth keeping?)
=======================================================
See project_files
List files belonging to project

l_error -> return errors for buffer or project

CONCEPTS > COMPLETIONS
==============================
Compeltions are simple:

An event with some data (see 'cell events completion' above) gets emitted, and
the cell should return a list of completions and starting point in line.

So given a line foo.add[' its fine if one completions completes from the last
'.', the other offers string completions from ' on.

Sample implementations:

  # use Vim's omnifunc
  call cells#viml#Cell({'traits': ['cells#examples#TraitCompletionFromCompletionFunction'], 'complete-functions': [{'complete-function': 'pythoncomplete#Complete', 'filetype_regex':'.', 'first_char_apply_match_score': 1}])

  # words from buffer
  call cells#examples#TraitTestCompletion({})

  # words from files of a project
  site-packages/cells/examples.py

completions based on words found in all files belonging to open buffers / files of project

Ideas:
If introduce a new event l_completion_has_strong_matches to only ask completion
providers which have strong matches first?gql

RULES OF THUMB I think make sense
=================================
They may help you make decisions

  * [Vim] In case of doubt assume that restarting Vim is cheap

TODO
====
  * While the word completion already works, add 'topics', like local var, local var with key, ..
    to make it easier to hit exactly what you're looking for.

    Current words in buffer also hit $foo['abc'] which often is nice, but not always.

  * switch files

  * completion triggered by key se toptions to select first hit

  * py3 switch to 'import logger' ?

  * language server client implementation

  * completion in python (for speed) and with caching (only ask once after . ..)

  * line based completion whole project

  * to n words completion if they occur very often nearby

  * Name completion in "Dear / Sehr geehrte .." in emails?

  * Implement closing whatever is open (tags brackets) ...
    <div><div> should complete to
      - </div>
      - </div></div>
    foo(( should completet to ) and ))

  * If local var completion and python completion both have options thing about
    which one to show or both or how to set priorities

  * For VimL Traits add code which updates cells (reruns functions) when files
    get written (life update)

  * Integrate YCM, Eclim, tools

  * completions after @ (host completion) within file / project files

  * integrate template engine

  * Talk about benefits and create videos/screenshots

  * from insert mode goto x nth element and maybe replace it
    (faster templating from similar lines)

  * continuations within context such as 'foo' then add => within PHP arrays

  * v -> completion popup for local vars because they are very likely to be used.
    for each language its own pattern such as  '(foo) = ' or do |a,b|

    Same about keyword such as f -> unction b -> reak r -> return - get list
    from syntax files of Vim?

  * eclim integration cell for completion and goto ?

  * http://sublimecodeintel.github.io/SublimeCodeIntel/ integration - there was
    a patch for YCM which eventually can be looked up easily

  * language server protocol implementation - pick from neovim python code ?

  * snippet engine integration for simple snipmate like snippet or ultisnips?
    I feel that a simple snipmate like implementation would be good enough

  

  * rename cell_list to list_cells?

  * implementation about 'accessing editor features' such as get lines, get
    cursor position to be independent of editor implementation.

  * kind of Buffer interface

  * implement remote RPC version ?

  * debug lines ?

  * actions()
    which could be turned into commands and or mappings
    [{'mode': 'normal/insert', 'action'}]

  * mappings()
  * commands()
  * aucommands()
  * menuitems() (I don't care)

  * provide_indentation_settings_for_file()
    purpose: figure out indentation based on your rules
    call the first time ou enter indent mode

  * virtual content provider for things like VCS files based on url, or run
    executable ?

    git:branch/file
    hg:branhc/file
    ...

    cell which shows signs
    [{<cell_id>, 'style': 'style representation', 'file': 'file', 'line': '...', 'text' : 'additional attached inforamtion', 'after_text': 'text to be shown below the item', 'actions': [<action>]}]
    after_text: more details about error

  * signs_to_be_shown()
    cell which shows signs
    [{<cell_id>, 'style': 'style representation', 'file': 'file', 'line': '...', 'text' : 'additional attached inforamtion', , 'fixit': [<action>]}]

  * footer_info()
    [{<cell_id>, 'text': .. 'prio': .., 'source': ...}]

  * move vim-dev-plugin completion into a cell as sample viml completion and
    goto thing at cursor / definition ?

  * Emacs & NeoVim Support

  * Python gather with timeout to catch issues (see examples.py, CompletionBasedOnFiles)

  * Plugin system to manage and update third party plugins

  * Python rewrite all the ask with ask_ syntax see def __getattr__(self, name) in class Cell in py3/site-packages/cells/__init__.py

  * CODOTO integration?

  * logfiles, allow cells to broadcast logfile locations ..

  * language server support:
     - for documentSymbol
     - for messages
     - refactoring (renaming)
     - formatting


LANGUAGES AND SOLUTIONS
=========================
Maybe help me find out what really works for languages almost all cases.

  PHP:
    completion definition like features
      intelephense -> testing, https://github.com/bmewburn/vscode-intelephense/tree/master/server
      crane -> testing, https://github.com/HvyIndustries/crane/issues/359, doesn't seem to work that well, sry
      felixfbecker -> https://github.com/felixfbecker/php-language-server -> no completion on A::
      Eclim -> Has sometimes problem completing top level (null pointer Exception), slower than the node solutions
      https://github.com/lvht/phpcd.vim -> could'nt make it work for trivial cases such as $this in same class or file_put_contents
      https://github.com/padawan-php/padawan.vim -> didn't try yet

  C/C++:
    See YCM ..
    GCC: https://www.phoronix.com/scan.php?page=news_item&px=GCC-LSP-Patch-Proposal ?

  typescript
    npm install typescript -> tsserver probably is the way to go

    syntax-vim: https://github.com/leafgarland/typescript-vim (one solution)

    -> TODO https://github.com/Microsoft/TypeScript/wiki/Standalone-Server-%28tsserver%29

    language-client: https://github.com/sourcegraph/javascript-typescript-langserver.git (



TODOS/ LINKS
============
  https://www.semanticscholar.org/paper/Contextual-Code-Completion-Using-Machine-Learning-Das-Shah/3d426d5d686db3dfa5cad88dbbf0bcf443828cf6


WHY?
====
Well - there has been a long war about which tools are best. Switching tools is
hard, because you have kind of lock in.

Lanugages people are used to or Editors want to be using:
  * Common denominator is JS/Typescript
  * NeoVim is heading towards lua
  * Vim has VimL (sucks for speed reasons) -> historically Python has been used most
  * Emacs -> Elisp
  * external tools (lanugage servers) are written in many languages
  * ....
=> so a choice cannot be made easily

Lua and python could be the same runtime:
  https://labix.org/lunatic-python

and JS is browser ready, but others are type safe or faster.
So .. - do what you want - but in a way others can reuse your work

So use whatever you know best



TODO:
=====
smart completion based on some chars.
ig for (c -> means always const) -> so have special meta key to complete this kind of trivial shit


EXAMPLES
========
fun TSCWatch() abort
  call SetupCells()
  let error_line_parsers = [
        \         'cells.asyncio.error_line_parsers.line_parser_tsc',
        \ ]
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.watch_cmd_errors.WatchCmdErrors', 'args': [], 'kwargs': {'id': 'py:external_process', 'new_run_regex': 'Watching forfile changes\.', 'cmd': 'tsc -w -p .', 'stdin_data': '', 'error_line_parsers' : error_line_parsers}})
endf

fun Fusebox_watch() abort
  " add restart options
    let load_cmd =  'load "foo.rb"\n'
    let error_line_parsers = [
    \         'cells.asyncio.error_line_parsers.line_parser_fusebox',
    \ ]
    call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.watch_cmd_errors.WatchCmdErrors', 'args': [], 'kwargs': {'id': 'py:external_process', 'new_run_regex': '^-------------------------|^--- FuseBox ', 'cmd': 'node fuse.js', 'stdin_data': load_cmd, 'error_line_parsers' : error_line_parsers}})
    nnoremap <F2> :call setqflist([])<bar>call cells.emit({'type': 'stdin_write', 'stdin_data': g:load_cmd, 'reset': true, 'selector': {"id": 'py:external_process'}})<cr>
endf

fun Webpack_watch() abort
  let t = tempname()
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.watch_cmd_errors.Webpack_watch', 'args': [], 'kwargs': {'cmd': 'webpack --watch | tee '.t}})
  echom 'webpack tmp is '.t
endf
fun TS() abort
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.tsserver.Tsserver', 'args': [], 'kwargs': {'connection_properties': {'cmd': 'tsserver'}}})
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.js_cell.JSCell', 'args': [], 'kwargs': {}})
  nnoremap <f4> :call g:cells.emit({'type': 'errors', 'filepath': expand('%:p')})<cr>
  nnoremap <f5> :call g:cells.emit({'type': 'errors', 'for_filepaths': [expand('%:p')]})<cr>
  nnoremap <f6> :call g:cells.emit({'type': 'showtype'})<cr>
  nnoremap <f7> :call g:cells.emit({'type': 'fix_error'})<cr>
  nnoremap <f8> :call g:cells.emit({'type': 'format_region'})<cr>
  nnoremap <f9> :call g:cells.emit({'type': 'rename', 'position': getpos('.')})<cr>
endf
fun Jedi()
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.python_jedi.JediCompletion', 'args': [], 'kwargs': {'id': 'JediCompletion'}})
endf
fun Dart() abort
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.language_server_protocol_client_dart_language_server.LanguageServerProtocolClientDart', 'args': [], 'kwargs': {'cmd': 'dart_language_server --log-directory /tmp/dart-log', 'id': 'DartCompletion'}})
endf
fun Tern()
  VAMActivate github:ternjs/tern_for_vim.git
endf

fun Tags()
  call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.examples.CompletionTAGS', 'args': [], 'kwargs': {}})
endf
" fun PHP() abort
"   call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.language_server_protocol_client_crane.LanguageServerProtocolClientCrane', 'args': [], 'kwargs': {'node_ipc': v:true, 'cmd': ['/run/current-system/sw/bin/node', '/pr/tasks/language-server/crane/client/server/server.js'], 'id': 'PHPCompletion'}})
" endf
" fun CSS() abort
"   call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.language_server_protocol_client.LanguageServerProtocolClient', 'args': [], 'kwargs': {'node_ipc': v:true, 'cmd': ['/run/current-system/sw/bin/node', '/pr/tasks/language-server/vscode-css-languageservice/lib/cssLanguageService.js'], 'id': 'CSSCompletion'}})
" endf
" fun HTML() abort
"   call g:bridge_cell.cell_new_by_name({'name': 'cells.asyncio.language_server_protocol_client.LanguageServerProtocolClient', 'args': [], 'kwargs': {'node_ipc': v:true, 'cmd': ['/run/current-system/sw/bin/node', '/pr/tasks/language-server/vscode-html-languageservice/lib/htmlLanguageService.js'], 'id': 'CSSCompletion'}})
" endf

nnoremap \sct :call SetupCells()<bar>call TS()<bar>echom "typescript setup"<cr>
nnoremap \sc :call SetupCells()<cr>
