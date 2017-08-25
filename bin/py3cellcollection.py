#!/usr/bin/env python
# cellcollection for py3 to be used as stdin/out

# minimal test, see TestPy3AsyncIO def testExternalAsyncIOTestScript, cat /tmp/x | pyton bin/py3cellcollection.py --controllernotreplying --debug --wait 2

import os
import asyncio
import sys

sys.path.append(os.path.dirname(__file__)+"/../py3/site-packages/")

import cells.asyncio as cells
from  cells.asyncio  import debug_str
import json
import copy
from asyncio.streams import StreamWriter, FlowControlMixin

import traceback

loop = asyncio.get_event_loop()
writer = None
receiving_cell_id = None
controllernotreplying = False

# EVENTS TO STDOUT
class CellEventToStdout(cells.Cell):
    def __init__(self):
        super(CellEventToStdout, self).__init__()

    async def l_emit(self, event):
        global receiving_cell_id
        global controllernotreplying
        if event['event']['origin_network'] != cells.cell_collection.prefix:
            return

        wait_for_id__for_requesting_cell = "%s-%s" % (cells.cell_collection.prefix, cells.cell_collection.id())

        if not controllernotreplying and 'reply_to' in event['event']:
          event['event']['wait_for'].append(wait_for_id__for_requesting_cell)

        event['event'] = copy.copy(event['event'])
        if not controllernotreplying and 'reply_to' in event['event']:
          event['event']['wait_for_id__for_requesting_cell'] = wait_for_id__for_requesting_cell

        async def print_event(event):
            global writer
            if 'async_def_futures' in event:
                for k in ['async_def_futures', 'async_def_result', 'reply_by', 'reply_now', 'reply_error_now', 'wait_for', 'results', 'reply_by']:
                    if k in event:
                        del event[k]
            # TODO speed up
            # print(">>", event)
            debug_str('sending stdout line: %s ' % json.dumps(event))
            writer.write((json.dumps(event)+"\n").encode('utf-8'))

        asyncio.ensure_future(asyncio.Task(print_event(event['event'])))


async def process_stdin_line(line):
    debug_str('got stdin line: %s' % line)
    global receiving_cell_id
    try:
        event = json.loads(line)
        if 'cell-collection-name' in event:
            # INITIALIZES CELL COLLECTION
            receiving_cell_id = event['receiving-cell-id']
            cells.cell_collection = cells.CellCollection(event['cell-collection-name'])
            cells.CellPy(id = "%s-%s" % (event['cell-collection-name'], "collection"))
            CellEventToStdout()
        elif 'set-loop-debug' in event:
            # see https://docs.python.org/3/library/asyncio-dev.html#asyncio-debug-mode
            # also run python with -Wdefault
            loop.set_debug(event['set-loop-debug'])
            logging.basicConfig(level=logging.DEBUG)
        elif 'test-exception' in event:
            raise Exception("test exception")
        else:
            await cells.emit(event)
            if 'wait_for_id__for_requesting_cell' in event:
                # return immediate results
                immediate_reply = cells.Cell.reply_event(event, {'results': event['results'], 'wait_for': event['wait_for'], 'wait_for_id': event['wait_for_id__for_requesting_cell']})
                debug_str('immediate reply %s' % (str(immediate_reply)))
                await cells.emit(immediate_reply)

    except Exception as e:
        # what to do with exceptions ? emit event to logging?
        import traceback
        debug_str(traceback.format_exc())


async def main_loop():
    global writer
    reader = asyncio.StreamReader()
    reader_protocol = asyncio.StreamReaderProtocol(reader)

    writer_transport, writer_protocol = await loop.connect_write_pipe(FlowControlMixin, os.fdopen(1, 'wb'))
    writer = StreamWriter(writer_transport, writer_protocol, None, loop)

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
    global controllernotreplying
    parser = argparse.ArgumentParser(description='async editor-cells collection implemented with asyncio in Python 3')
    parser.add_argument('--wait', metavar='N', type=int, help='wait for finish 0 means forever')
    parser.add_argument('--debug', help='trace additional information to stdout', action = "store_true")
    parser.add_argument('--controllernotreplying', help='for testing, do not assume programm connecting to stdin/out is replying', action = "store_true")
    # parser.add_argument('--status-file', type=string, nargs='+', help='status file async debug')
    args = parser.parse_args()

    if args.wait is None:
        args.wait = 2

    if not args.debug is None:
        cells.debug = True

    if args.controllernotreplying:
        controllernotreplying = True

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
