#!/usr/bin/env python
# cellcollection for py3 to be used as stdin/out

# minimal test:
# echo -ne '{"set-cell-collection-name":"py3test", "origin_network": "sthelse"}\n{"set-loop-debug":true}\n{"type":"cell_collections", "wait_for_id__for_requesting_cell": "dummy_id", "reply_to": "dummytarget", "request_id": "r1"}\n{"wait_for_id__for_requesting_cell": "dummy_id", "type":"cell_list", "reply_to": "dummytarget", "request_id": "r3", "origin_network":"sthelse" }\n{"type": "dummy", "reply_to": "dummytarget", "request_id": "r5", "wait_for_id__for_requesting_cell": "dummy_id", "origin_network": "sthelse"}' |  PYTHONPATH=py3/site-packages python -Wdefault bin/py3cellcollection.py
# {"set-loop-debug": true, "origin_network": "py3test"}
# {"type": "cell_collections", "origin_network": "py3test"}
# {"type": "cell_list", "origin_network": "py3test"}
# {"type": "reply", "wait_for_id": "dummy_id", "wait_for": [], "results": [], "selector": {"id": "doesnotexist"}, "origin_network": "py3test"}

import os
import asyncio
import sys
sys.path.append("py3/site-packages/")
import cells.asyncio as cells
from  cells.asyncio  import debug_str
import json
import copy
from asyncio.streams import StreamWriter, FlowControlMixin

loop = asyncio.get_event_loop()

# EVENTS TO STDOUT
class CellEventToStdout(cells.Cell):
    def __init__(self, writer):
        self.writer = writer
        super(CellEventToStdout, self).__init__()

    async def l_emit(self, event):
        if event['event']['origin_network'] != cells.cell_collection.prefix:
            return

        async def print_event(writer, event):
            if 'async_def_futures' in event:
                event = copy.copy(event)
                for k in ['async_def_futures', 'async_def_result', 'reply_by', 'reply_now', 'reply_error_now']:
                    if k in event:
                        del event[k]
            # TODO speed up
            # print(">>", event)
            writer.write((json.dumps(event)+"\n").encode('utf-8'))

        asyncio.ensure_future(asyncio.Task(print_event(self.writer, event['event'])))

async def process_stdin_line(line):
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
            await cells.emit(event)
            if 'wait_for_id__for_requesting_cell' in event:
                e = {'request_id': event['request_id'], 'type': 'reply', 'wait_for_id': event['wait_for_id__for_requesting_cell'], 'wait_for': event['wait_for'], 'results': event['results'], 'selector': {'id': event['reply_to']}}
                await cells.emit(e)
                if 'wait_for_id__for_requesting_cell' in event:
                    # return immediate results
                    immediate_reply = cells.Cell.reply_event(event, {'results': event['results']})
                    immediate_reply['wait_for'] = event['wait_for']
                    await cells.emit(immediate_reply)

    except Exception as e:
        # what to do with exceptions ? emit event to logging?
        import traceback
        sys.stderr.write(traceback.format_exc())


async def main_loop():
    reader = asyncio.StreamReader()
    reader_protocol = asyncio.StreamReaderProtocol(reader)

    writer_transport, writer_protocol = await loop.connect_write_pipe(FlowControlMixin, os.fdopen(1, 'wb'))
    writer = StreamWriter(writer_transport, writer_protocol, None, loop)

    CellEventToStdout(writer)
    cells.CellPy()

    await loop.connect_read_pipe(lambda: reader_protocol, sys.stdin)
    while True:
        line = await reader.readline()
        if len(line) > 0:
            await process_stdin_line(line)
        if reader.at_eof():
            # stdin means quit
            break
    # writer.close()

def main():
    import argparse
    parser = argparse.ArgumentParser(description='async editor-cells collection implemented with asyncio in Python 3')
    parser.add_argument('--wait', metavar='N', type=int, help='wait for finish 0 means forever')
    # parser.add_argument('--status-file', type=string, nargs='+', help='status file async debug')
    args = parser.parse_args()

    if args.wait is None:
        args.wait = 2

    loop.run_until_complete(main_loop())

    all_tasks = asyncio.Task.all_tasks()
    debug_str(len(all_tasks))
    if len(all_tasks) > 0:
        sys.stderr.write('STDIN closed, %s tasks remaining, will wait %s secs\n' % ( len(all_tasks), args.wait) )
        for t in all_tasks:
            t.print_stack()
        if args.wait != None:
            async def wait():
                await asyncio.wait(all_tasks, timeout = args.wait)
            loop.run_until_complete(wait())
            all_tasks = asyncio.Task.all_tasks()
            if len(all_tasks) > 0:
                all_tasks = asyncio.Task.all_tasks()
                sys.stderr.write('%s tasks unfinished after waiting, exiting\n' % len(all_tasks))


if __name__ == "__main__":
    main()
