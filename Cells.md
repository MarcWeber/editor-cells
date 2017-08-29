Some cells and features
=======================

List some cells and what they do

features
--------------------
completion
c,cpp,java (like ft in Vim)


cells
=====

Vim implementations:
--------------------
cells#examples#TraitCompletionLastInsertedTexts(cell)
tags: [completion]
description: complete from last insterted texts

cells#examples#TraitCompletionLocalVars(cell)
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
description: add completions from Vim completion function

cells#examples#TraitDefinitionsAndUsages
description: allows to use l_definitions and l_usages within Vim

Python implementations
----------------------
py3/site-packages/cells/asyncio/examples.py:

CompletionBasedOnFiles 
tags: [completion]
description: Python implementation completing words from project files or Vim buffer files

JediCompletion:
tags: [completion]
description: Python completion, definiton, usages based on Jedi
