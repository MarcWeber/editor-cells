#!/usr/bin/env python
# cellcollection for py3

# minimal test:
    # echo -ne '{"set-cell-collection-name":"py3test", "origin_network": "sthelse"}\n{"set-loop-debug":true}\n{"type":"cell_collections", "wait_for_id__for_requesting_cell": "dummy_id", "reply_to": "dummytarget", "request_id": "r1"}\n{"wait_for_id__for_requesting_cell": "dummy_id", "type":"cell_list", "reply_to": "dummytarget", "request_id": "r3", "origin_network":"sthelse" }\n{"type": "dummy", "reply_to": "dummytarget", "request_id": "r5", "wait_for_id__for_requesting_cell": "dummy_id", "origin_network": "sthelse"}' |  PYTHONPATH=py3/site-packages python -Wdefault py3cellcollection.py
# {"set-loop-debug": true, "origin_network": "py3test"}
# {"type": "cell_collections", "origin_network": "py3test"}
# {"type": "cell_list", "origin_network": "py3test"}
# {"type": "reply", "wait_for_id": "dummy_id", "wait_for": [], "results": [], "selector": {"id": "doesnotexist"}, "origin_network": "py3test"}

import os
import asyncio
import sys
import cells.asyncio as cells
import json
import copy
from asyncio.streams import StreamWriter, FlowControlMixin

loop = cells.cell_collection.asyncio_loop

# EVENTS TO STDOUT
class CellEventToStdout(cells.Cell):
    def __init__(self, writer):
        self.writer = writer
        super(CellEventToStdout, self).__init__()

    def l_emit(self, event):
        if event['event']['origin_network'] != cells.cell_collection.prefix:
            return

        @asyncio.coroutine
        def print_event(writer, event):
            if 'future_result' in event:
                event = copy.copy(event)
                del event['future_result']
            # TODO speed up
            writer.write((json.dumps(event)+"\n").encode('utf-8'))

        loop.call_soon(lambda: asyncio.ensure_future(print_event(self.writer, event['event'])))

# INPUT LOOP

@asyncio.coroutine
def process_stdin_line(line):
    try:
        event = json.loads(line)
        if 'set-loop-debug' in event:
            # see https://docs.python.org/3/library/asyncio-dev.html#asyncio-debug-mode
            # also run python with -Wdefault
            loop.set_debug(event['set-loop-debug'])
            # logging.basicConfig(level=logging.DEBUG)
        elif 'set-cell-collection-name' in event:
            # special dictionary setting prefix
            cells.cell_collection.prefix = event['set-cell-collection-name']
        elif 'test-exception' in event:
            raise Exception("test exception")
        else:
            cells.emit(event)
            if 'wait_for_id__for_requesting_cell' in event:
                e = {'request_id': event['request_id'], 'type': 'reply', 'wait_for_id': event['wait_for_id__for_requesting_cell'], 'wait_for': event['wait_for'], 'results': event['results'], 'selector': {'id': event['reply_to']}}
                cells.emit(e)

    except Exception as e:
        # what to do with exceptions ? emit event to logging?
        import traceback
        sys.stderr.write(traceback.format_exc())

@asyncio.coroutine
def main():
    reader = asyncio.StreamReader()
    reader_protocol = asyncio.StreamReaderProtocol(reader)

    writer_transport, writer_protocol = yield from loop.connect_write_pipe(FlowControlMixin, os.fdopen(1, 'wb'))
    writer = StreamWriter(writer_transport, writer_protocol, None, loop)

    CellEventToStdout(writer)
    cells.CellPy()

    yield from loop.connect_read_pipe(lambda: reader_protocol, sys.stdin)
    while True:
        line = yield from reader.readline()
        if len(line) > 0:
            yield from process_stdin_line(line)
        if reader.at_eof():
            break

    writer.close()

asyncio.get_event_loop().run_until_complete(main())
