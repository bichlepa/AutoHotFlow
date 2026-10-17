# WI-0080 Log display in the manager

Size: M · Depends on: WI-0073 · Blocks: WI-0082

## Goal

The manager shows the log: the recent entries from the file and new ones live, filtered by level and by source (app, flow, thread) and by flow. The window stays responsive with a burst of log lines. Requirement: REQ-MGR-070.

## Read first

As WI-0073, plus PROTOCOL 4.6 (`evt.log.append`, the log files, topic `log`, rotation), `src/storage/LogSink.ahk`, `src/storage/Storage.ahk`; MS-0017 and MS-0022 to MS-0024 (log floods); v1 `Button_manager_ShowLog` in `Manager GUI.ahk`.

## Tasks

1. **Docs first:** PROTOCOL 4.6: `cmd.storage.log.tail` (the last n entries of `Log.txt`, or of one source file, parsed into `{ts, level, source, flowId?, text}`; a limit on n and on the size of the answer).
2. **Manager:** a log window that loads the tail and subscribes to topic `log` only while it is open; filters by level digit, source group and flow; a limit of the lines in the window (the oldest go); a burst is drawn in batches (no redraw per line).
3. **Flow log:** a way to open the window filtered to one flow (the flow settings of S0007 call it).
4. **Tests:** e2e headless: the tail is read, new entries arrive, the filters, the topic subscription ends when the window closes; a burst of 5000 lines does not stall the manager (it keeps answering pings, and the model keeps at most the limit).

## Acceptance criteria

- The tests of task 4 are green, serial and parallel.

## Not part of this

Settings of the log (WI-0077, WI-0078).
