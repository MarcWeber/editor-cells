#!/usr/bin/env python

# TODO handle exceptions and the like

# cellcollection for py3
import asyncio
import cells.py
import cells
import json

loop = cells.py.cell_collections.loop


# EVENTS TO STDOUT
class CellEventToStdout(Cell):

    def __init__(self):
        super(CellEventToStdout, self).__init__()

    def l_emit(self, event):
        if event['event']['origin_network'] == cell_collection.prefix:
            print json.dumps(event['event'])

CellEventToStdout()

# EVENTS FROM STDIN, MAIN LOOP, FOREVER
def main():
    while True:
        line = yield from reader.readline()
        event = json.loads(line)
        if 'cell-collection-name' in event:
            # special dictionary setting prefix
            cells.py.cell_collections.cell_collection.prefix = event['cell-collection-name']
        elif 'new-cell-instance' in event:
            # {'new-cell-instance': 'foo.bar.Cell', ('args': [], 'kargs': {} )}
            # special event allowing to instantiate a cell easily
            module_and_class = event['new-cell-instance']
            i = __import(event[module_and_class[0:-2])
            get(i, event[module_and_class[-1]])(*event.get('args', []), **event.get('kargs', {}))
        else:
            cells.emit(event)

asyncio.get_event_loop().run_forever(main())
