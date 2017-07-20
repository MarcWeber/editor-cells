editor-cell (Ending part of the editor war / like evolution)
=============================================
There important pieces you start loving you want to use in all editing
environments.
BUT: They are written in Java,C,JS,ELisp (Eclipse, (Neo)Vim, vscode, Emacs, ..)
Its even worse: VimL is slow, NeoVim introduces its own RPC, ...

So how to reuse your code pieces (=cells) ?
Redefine your interfaces as events
Add code for editors to use it.

One cell says:
  "I have an compilation result output - who wants to show it?"
Another cell replies
 "My task is to show it, so send details to me"

Same about signs, completions, ..

So you setup your system the way you want !
If you don't like an implementation replace it.

CAUTION: The code may still change ..

BUT WHAT IS IMPORTANT TO YOU
==============================
  * A working system
  * reusing your code across system
  * reusing 'muscle memory' because it takes time to rebuild


Which programming language should be default?
===================
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

WHAT IS A CELL?
===================
A cell has
  - has an id such as 'viml:20'
  - At least one purpose such as "I provide signs"
  - can talk to other cells by receiving and sending events
Some porcelain is be provided for making async conversations easier

LIMITS
======
Well, eventually it does not make sence to use cells to define highlighting or
folding or similar (?) - to be seen. But things like smartest completion ever
with machine learning what is is used most in context and the ilke.

For instance if you're within a foreach(.. as $x) its highly likely that you're
going to use $x

EVENTS
======
An event is a dictionary which can be serialized (such as JSON) because most
languages understand it. Values should not contain 0 bytes (VimL restriction ?).

Special keys:

  type: All events have it

  reply_to: <cell_id> If cells should sent back a reply emit an event to this.
            Use one of the following reply types:
            {'error': string}
            {'value': string}
            {'wait_for': [<list of cell ids>]}
  request_id:  Only makes sens if reply_to is used. When replying pass the same
               id so that asking cell knows which question the reply belongs to

  timeout_sec: optional: If you know that you don't want to wait forever set a time limit here.

  sender: <cell-id>, for instance when sending replies

  wait_for: [] list of cell_ids to be wait for till the result is complete (async replies)
  results:  [] list you can add results to (immediate replies). The result should have the form {'result/error': ..}

  A listening event can return 
    "wait_for" : [<my-id>]
    "results"  : [<my-id>]

  rather than sending an event.

EVENTS VIML implementation (autoload/cells.vim (API) and autoload/cells/viml.vim)
===================

let cell = cells#viml#Cell({}) " this will already register the cell globally

" listen to event_name
fun! cell.l_<event_name>(event)
  call self.reply_now(a:event, <result>)

  " or if you want to reply later:
  call add(a:wait_for, self.id) " notify that a reply will happen
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




SPECIAL EVENTS / CONCEPTS / COMMON FEATURES
============================================

" results:
If an eveisnt has key 'reply_to' it indicates that a cell should reply. You can
add a 'request_id' which if present should be included in the reply

" internal use:

" core events which should be implemented by each target
  { 'type': 'emit', }  emit event to all cells, also see emit_to_one
  { 'type': 'cell_collections', }   => reply {'prefix': ..., 'details': ...}
  { 'type': 'cell_collection_added'}   => reply {'name'}
  { 'type': 'cell_kill', selector: ..} # kills cells matching selector
  { 'type': 'cell_list', 'selector': ... } # reply list of ids of cells matching selector, see cells#viml#CellsBySelector

" events about cells
  { 'type': 'killed', 'sender': .. } # 
  { 'type': 'properties_changed', }


# introspection: todo

{ 'type': 'set_properties', 'properties': {'enabled': v:false} }
{ 'type': 'log', 'lines': [], 'prio': TODO, 'sender': optional cell_id }
{ 'type': 'killed': sender: 'cell-id' } " if other cells might depend on a cell it can notify the other cells that it has been killed

{ 'type': 'definition'} -> [{<cell_id>, 'text': 'mulitiline text', <location_keys>}]

{ 'type': 'info_about_thing_below_cursor' } -> [{<cell_id>, 'text': 'mulitiline text', <location_keys>}]

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
    "context_lines": []
    'line_split_at_cursor':
    'position': # see getpos('.')
    'limit': 500
    'match_types': ['prefix', 'ycm', 'camel_case_like']
  }

  reply => 
  [
    { 'column': .., 'context': 'default', 'completions': [{'word', 'word_propability', 'description', 'continuation' : '..', 'certainity' => float}] }
  ]

  word: the word to be inserted
  word_propability: if you want to do probability analysis use this instead
      (for instance php has two different kinds of foreach you may want to
      differentiate in word such as for_k for_v but know how ofte its used by looking
      at word foreach instead)
  description:
  .. see completions keys

  Set context to something different to 'default' if you think you found a
  context making this completion much more likely to match, such as after
  background-color in css

  The code showing the completions might use this information for both:
  Calculating probabilities or disregarding other completions or showing them first

  <location_keys>: file, line
  <action>: action which can be run


# cell events filetype
{' 'type': 'ftdetect' }
=> reply 'js' or such
  
# cell events core editor events
{ 'type': 'bufenter', 'bufnr': .., 'filename': .. } # au trigger: BufEnter
{ 'type': 'bufnew', 'bufnr': .., 'filename': .. }   # au triggers: BufNewFile,BufRead
{ 'type': 'filetype', 'bufnr': .., 'filename': .. } # ....

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
{ 'type': 'editor_buffers', 'keys': ['id', 'filename', 'modify_state'] } # subscribe to features / events
  -> reply { 'buffers': [{'id': .., 'filename': ..}, 'modify_state': }]}

features:
  ['editor_bufopen', 'editor_bufclose', 'editor_buf_written', 'editor_buf_cursor_pos']
   {"type': 'editor_bufnew',     'bufid': <bufid>, 'filename'}
   {"type': 'editor_bufread',     'bufid': <bufid>, 'filename'}
   {"type': 'editor_bufclose',    'bufid': <bufid>, 'filename'}
   {"type': 'editor_buf_written', 'bufid': <bufid>, 'filename'}
   {"type': 'editor_buf_changed', 'bufid': <bufid>, 'filename'}
   # {"type': 'buf_cursor_pos',     'bufid': <bufid>, 'filename'} TODO

EVENT REPLIES
==========================
Its ugly: Multiple processes will be running its required to keep track of
which replies to wait for.

See autoload/cells/tests.vim -> ask_all() which serves as sample.

CELL COLLECTIONS
=========================
Each language has its own set of cells and some cells taking care
of passing communication between them.

Care has to be taken that the same event doesn't cause a loop when setting
up the event forwarding.

The recommended way is to have all collections forward the events to one main
collection which forwards the events to all collections except the
origin_network.

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

  <location_keys>: file, line
  <action>: action which can be run

  * definition():
    [{<cell_id>, 'text': 'mulitiline text', <location_keys>}]

  * info_about_thing_below_cursor()
    [{<cell_id>, 'text': 'mulitiline text', <location_keys>}]

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

IMPLEMENTATIONS / COMPLETIONS
==============================
completion based on current buffer: cells#examples#TraitTestCompletion site-packages/cells/examples.py

completions based on words found in all files belonging to open buffers / files of project

RULES OF THUMB
===============
* In case of doubt assume that restarting Vim is cheap

TODO
======
  * implementation about 'accessing editor features' such as get lines, get
    cursor position to be independent of editor implementation.

  * goto ID like thing showing full lines -> this works good enough like tags
    (search all files in project), but allow configurating files to be searched by glob patterns

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

  * Announce at Reddit after some Emacs support has been written?

  * replace bufnr by bufid beacuse bufnr is special to Vim

TIPS:
=====
  Debbungi VimL See
  if cells#examples#vim_dev#GotoFirstError() | cfirst | endif


TODOS/ LINKS
============
  https://www.semanticscholar.org/paper/Contextual-Code-Completion-Using-Machine-Learning-Das-Shah/3d426d5d686db3dfa5cad88dbbf0bcf443828cf6
