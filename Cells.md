Some cells and features
=======================

List some cells and what they do

features
--------------------
completion
c,cpp,java,python (like ft in Vim)


cells
=====

Vim implementations:
--------------------
cells#examples#TraitCompletionLastInsertedTexts(cell)
tags: [completion]
description: complete from last insterted texts

cells#examples#TraitCompletionContext(cell)
tags: [completion]
description: complete some local vars those regex detect

cells#examples#TraitTestCompletionThisBuffer(cell)
tags: [completion]
description: complete from current buffer (Python implementation CompletionBasedOnFiles might be faster)

cells#examples#TraitTestCompletionAllBuffers(cell)
tags: [completion]
description: complete from all buffers (Python implementation CompletionBasedOnFiles might be faster: TODO)

cells#examples#TraitCompletionFromCompletionFunction(cell)
tags: [completion]
description: add completions from Vim completion function. Eg wrapper for Eclim completion

cells#examples#TraitDefinitionsAndUsages
description: allows to use l_definitions and l_usages within Vim

cells#examples#PathCompletion
description: smart path completion completing after PATH=... based on Vim's glob function

Python implementations
----------------------
py3/site-packages/cells/asyncio/examples.py:

CompletionBasedOnFiles 
tags: [completion, definition]
description: Python implementation completing words from project files or Vim buffer files

cells.asyncio.python_jedi.JediCompletion:
tags: [completion, definition, python]
description: Python completion, definiton, usages based on Jedi

cells.asyncio.eclim.Eclim
tags: [completion, definition, python, ruby, scala, java, php, css, html]
description: Eclipse based headless completion, see eclim.org. Tested for PHP, should be easy to add more languages

cells.asyncio.language_server_protocol_client.LanguageServerProtocolClient
tags: [completion, definiton]
description: See http://langserver.org/, some features are still missing
