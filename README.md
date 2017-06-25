editor-cell / GOALS
=============================
There important pieces you start loving you want to use in all editing environments.
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
  - A purpose such as "I provide signs"
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


SPECIAL EVENTS / CONCEPTS / COMMON FEATURES
============================================

" results:
If an eveisnt has key 'reply_to' it indicates that a cell should reply. You can
add a 'request_id' which if present should be included in the reply

" internal use:


" core events which should be implemented by each target
  { 'type': 'emit', }  emit event to all cells, also see emit_to_one
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

" === completions
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
    { 'column': .., 'context': 'default', 'completions': [{'word', 'description', 'continuation' : '..', 'certainity' => float}] }
  ]

  Set context to something different to 'default' if you think you found a
  context making this completion much more likely to match, such as after
  background-color in css

  The code showing the completions might use this information for both:
  Calculating probabilities or disregarding other completions or showing them first

  <location_keys>: file, line
  <action>: action which can be run


" === filetype
{' 'type': 'ftdetect' }
=> reply 'js' or such
  
" === commonly used au commands as events 
TODO
{ 'type': 'bufenter', 'bufnr': .., 'filename': .. } # au trigger: BufEnter
{ 'type': 'bufnew', 'bufnr': .., 'filename': .. }   # au triggers: BufNewFile,BufRead
{ 'type': 'filetype', 'bufnr': .., 'filename': .. } # ....

" === mappings
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

" === signs
{'type': 'signs_changed', 'sender': 'cell-id'}
{'type': 'signs',  'limit': 500, 'for_buffers': [{bufnr: ..,  expanded: .. , name: ..}] }
=> [{'bufnr': bufnr, 'name': '', 'definition': 'text=-', 'catgeory': 'fooo', 'signs': [{line, comment}] ]
Example implementation see autoload/cells/vim8.vim and autoload/cells/tests.vim

" === quickfix
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


EVENT REPLIES (MAP REDUCE)
==========================
Its ugly: Multiple processes will be running its required to keep track of
which replies to wait for.

Sample implementation see cells#viml#CollectRepliesCell(cell).
See key reply_to above


VIML sample implementation:


viml``
    let collector = cells#viml#CellReplyCollector({})
    fun! collector.killed() abort
      echoe self.results
    endf
    let a:event.reply_to = a:reply_collector_cell_id
    call cells#emit({'type': 'completions', 'reply_to': collector.id, 'timeout_sec': 40}, a:selector)
    If you want to reduce on each step overwrite collector.result()
``

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

  * completions(fast/slow)
    [{<cell_id>', type, text, <opts> }]

      opts can be 
      prefix: only showing completions starting with prefix
      filter-regex: only keep items matching this regex
                    A completion strategy could be 

  * templates()

  * debug lines ?

  * actions()
    which could be turned into commands and or mappings
    [{'mode': 'normal/insert', 'action'}]

  * autocommands ?

  * provide_indentation_settings_for_file()
    purpose: figure out indentation based on your rules
    call the first time ou enter indent mode

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
==================================
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

RULES OF THUMB
===============
* In case of doubt assume that restarting Vim is cheap

TODO
======
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

