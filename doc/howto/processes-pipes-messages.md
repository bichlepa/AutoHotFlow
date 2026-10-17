# How-to AHK v2: Processes, pipes, messages

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### Pipe reads and writes in parallel only with overlapped I/O

- **Problem:** A Python client needs a read thread while the main thread writes. With a synchronous handle (`open(..., "r+b")`) Windows serializes the I/O, so a pending read blocks the write. The `OVERLAPPED` structure must have matching field sizes, otherwise `hEvent` is read from the wrong offset.
- **Right:** Open the pipe with `FILE_FLAG_OVERLAPPED`, with its own OVERLAPPED structure and event per direction. Serialize writes with a lock; run reads with a timeout via `WaitForSingleObject` and `CancelIoEx`. Build the structure with `ctypes.Structure`: `c_size_t` for `Internal`/`InternalHigh`, `DWORD` for `Offset`/`OffsetHigh`, `HANDLE` for `hEvent`; pass buffers as integers via `ctypes.addressof(...)`.
- **Status:** verified (`tests/support/test_client_hub.py`, request and reply while the read thread runs; the structure layout: tests pass with read and write buffers, `tests/support/winpipe.py`). The synchronous case itself: assumed.
- **Source:** `tests/support/winpipe.py`


### `PostMessageW` with a NULL handle reports success

- **Problem:** A test expected `False` for `PostMessageW(0, ...)` (no window). The call returns `TRUE`.
- **Right:** For "window does not exist", use a real, destroyed window handle. Do not use the return value of `wake()` as an error check.
- **Status:** verified (failing test, then removed)


### AHK overlapped pipe I/O with DllCall (pattern that works)

- **Problem:** Server and client need non-blocking pipes in AHK v2, without threads.
- **Right:**
  - `OVERLAPPED` as `Buffer(32, 0)`, event from `CreateEventW` (manual reset, not signaled) at offset `2*A_PtrSize + 8`. Keep structure, buffer and event as members, never as locals.
  - Read: `ResetEvent`, then `ReadFile(h, buf, n, 0, ov)` (a `NULL` byte counter is allowed with overlapped I/O). Return 0 with `A_LastError = 997` is normal. Never check completion with `WaitForSingleObject` after a return of 0; use `GetOverlappedResult(h, ov, &n, 0)`: 0 with error `996` (`ERROR_IO_INCOMPLETE`) means "not yet", any other error means the end. This also applies when `ReadFile`/`WriteFile` returned `TRUE` immediately.
  - Other side gone: `109` (`ERROR_BROKEN_PIPE`) on read, `232` or `109` on write. A read of 0 bytes in byte mode is also the end.
  - Close: `CancelIoEx(h, 0)`, wait (bounded) for the pending operations, only then `CloseHandle` and free the buffers. Frames written before the close remain readable by the other side.
  - Server: one waiting instance per `PipeListener`. `ConnectNamedPipe` can return `535` (`ERROR_PIPE_CONNECTED`): treat it as connected. Create the next instance before handing over the connected one, so a client never sees "not found".
  - Client: `CreateFileW` with retry on `2` and `231`. To wait, use `DllCall("Sleep")` and `WaitNamedPipeW`: AHK's own `Sleep` processes messages and would run timers and wake-up calls in the middle of the connection setup.
- **Status:** verified (`tests/integration/test_pipe.py`, 26 tests, with a Python peer and an AHK peer). That AHK's `Sleep` processes messages is from the documentation and not measured separately.
- **Source:** `src/core/ipc/PipeConnection.ahk`, `src/core/ipc/PipeListener.ahk`


### The wake-up call covers writing only; a follow-up timer drains the queue

- **Problem:** The wake-up message (`WM_AHF_WAKE`) says "data written", not "data read". A pending overlapped write and a connection break produce no message, so draining large frames stalled at 250 ms per frame.
- **Right:** (1) If a connection still has frames queued, `SendFrame`/`Pump` schedules a follow-up pump with `SetTimer(fn, -1)`. (2) A fallback timer (250 ms) detects connection breaks and new clients. Measured: the end of a process is noticed after 42 to 98 ms; a new connection without a wake-up call is accepted within about 250 ms. Clients should send a wake-up call after connecting. For Python clients: median response 226 ms without the wake-up call, 1.4 ms with `PostMessage(WM_AHF_WAKE)` after each write (10 runs). A Python hub that does not wake the receiver adds 250 ms per message direction, so the test hub must wake too (`WakingHub` in `tests/integration/test_peer.py`).
- **Status:** verified (measurements in test runs). Behavior with many clients in the real hub was not checked.
- **Source:** `src/core/ipc/Wake.ahk`, `src/core/ipc/PipeConnection.ahk`, `tests/stress/stresskit.py`


### Re-entry: Pump, SendFrame, handlers and the lock of a connection interrupt each other

- **Problem:** AHK threads are interrupted after 15 ms of run time by timers and messages. An `OnFrame` handler that calls `SendFrame`, and an interrupting `Pump`, access the same queues. Also, the check of a state transition and the following action can be interrupted between two lines: a timer that interrupted between check and start started an element twice. The re-entry lock makes "pump first" ineffective as well: the supervisor calls `hub.Pump()` first, so that an unread `sys.bye` is read before the end of a process is judged. If the tick interrupts a `Pump` of the same connection (woken by the wake-up call, running longer than 15 ms), the lock only sets "again" and returns; the `sys.bye` stays unread and the end is judged `clean: false`.
- **Wrong:** Relying on a call to `Pump()` "reading everything now". With the lock it only means "it will be read, in this or another thread".
- **Right:** Per connection, guard flags (`_pumping`, `_writing`) with an "again" flag. Wrap check and set in `prev := Critical("On") ... Critical(prev)`, because two separate lines could be interrupted; `Critical("On")` returns the previous setting. Act on the result of a transition (`if (!thread.Dispatch()) return`) and keep check and state change in one `Critical` block. Catch and log handler errors, so the state machine is not left half-finished. Defer `OnClose` from `SendFrame` with `SetTimer(fn, -1)`. Judge a terminated process only when its connection has been read to the end (`Hub.HasLink` false), or after a grace period (500 ms); during this time the child counts neither as hanging nor as killed.
- **Status:** verified for the connection function (12000 ping-pong runs without a lost wake-up; `Tick` test red with 2 starts, green with 1; unit test `Tick: an exit is not judged while another pump still reads the connection of the child` in `tests/ahk/supervisor_tick.test.ahk`). The guards against a real interruption were not reproduced on demand, and that the lock race happened in the real supervisor: assumed.
- **Source:** `src/core/ipc/PipeConnection.ahk`, `src/engine/Executor.ahk` (`Tick`), `src/supervisor/Children.ahk` (`_ExitReadable`, `Terminate`, `MarkHung`)


### Handler return: only an empty value counts as "no result"

- **Problem:** `Dispatcher.Invoke` treated every non-object return value as "no return", so a handler returning `"text"` got `ok:true`.
- **Wrong:** `if (!IsObject(result)) return Map("ok", true)`.
- **Right:** `if (!IsObject(result) && result == "")` gives `ok:true`. Any other non-Map return becomes an `internal` error.
- **Status:** verified (test "a handler returning a non-Map is an internal error" was red, then green; `tests/ahk/dispatcher.test.ahk`)
- **Source:** `src/core/ipc/Dispatcher.ahk`


### Connection setup without blocking: one attempt, retry via timer

- **Problem:** `PipeConnection.Connect(name, 3000)` waits up to 3 s with `Sleep` in the caller. A peer that waits for the hub at startup stalls its message path for that long.
- **Right:** `PipeConnection.Connect(name, 0)` makes exactly one attempt and throws at once. The peer retries via `SetTimer` with backoff (100 ms, 200, 400, ... at most 2 s) and reports `hub_unreachable` after 10 s.
- **Status:** verified (`test_hub_gone_for_longer_than_the_budget_calls_onclosed`, `test_reconnect_after_hub_restart_resubscribes_and_reports_ready_again`)
- **Source:** `src/core/ipc/Peer.ahk` (`_Attempt`, `_ScheduleRetry`)


### One timer per request, switched off on reply

- **Problem:** Every request needs a timeout, and AHK offers no count of active timers.
- **Right:** One `SetTimer(fn, -timeoutMs)` per request; on reply `SetTimer(fn, 0)`. Count open requests with `Peer.PendingCount` (must be 0 at the end).
- **Status:** verified (10,000 sequential requests: handle count constant at 163, 0.99 ms per request)
- **Source:** `tests/integration/test_peer.py::test_10000_sequential_requests_keep_pending_and_handles_flat`


### `sys.shutdown`: do not close the connection inside the frame handler

- **Problem:** `sys.shutdown` must send `sys.bye` and then end the process. Closing the peer inside the frame handler closes the connection while it is still processing the frame.
- **Right:** In the handler only set `SetTimer(Role.ByeFn, -1)`. The timer sends `sys.bye {clean:true}`, closes with `Peer.CloseWhenFlushed` (see "Close discards the send queue"), and calls `ExitApp(0)` in the callback.
- **Status:** verified (`test_shutdown_sends_bye_and_exits_0_within_one_second`: exit 0 about 240 ms after the command). A direct `Close` in the handler was not tried.
- **Source:** `src/core/Role.ahk` (`_OnShutdown`, `_FinishShutdown`)


### Orphan guard: measure the deadline in its own timer

- **Problem:** The peer retries the connection setup for up to 10 s, but a role must end after 3 s without hub, so it needs its own clock.
- **Right:** A timer (200 ms) reads `peer.status`. While it reads `reconnecting`, the timer records the time. After 3 s without `ready` it calls `ExitApp(4)`.
- **Status:** verified (`test_hub_gone_role_ends_within_orphan_budget_and_leaves_no_process`: end 3.25 s after the hub stopped, no process left). The start of the deadline is accurate to about 200 ms.
- **Source:** `src/core/Role.ahk` (`_Guard`)


### A message sent before the receiver is connected or subscribed is lost

- **Problem:** (a) A client that subscribes after startup does not receive earlier `evt.process.*` events. Waiting for an event that came before the subscription waits forever. (b) `Shutdown._SendGroup` sent `sys.shutdown` once to each group. A child that was still starting had no connection yet: `Hub.Send` returned `false`, and nobody noticed. The child reported itself later, never got `sys.shutdown`, and was killed at the deadline (exit 5). Treating "sent" as "delivered" is wrong when the receiver cannot be reached yet.
- **Wrong:** Waiting for an event that was sent before `cmd.topic.subscribe`; sending once and treating "sent" as "delivered".
- **Right:** (a) Subscribe first, then fetch the state as a snapshot (`cmd.process.list` at the supervisor, `cmd.engine.snapshot` at the engine); process events afterwards. A readiness event (`ready`) does not mean that the content is loaded: after `ready`, poll `cmd.engine.snapshot` until the flows appear. (b) On the event that makes delivery possible (`sys.hello`), catch up on the target's state: `Shutdown.OnHello` sends `sys.shutdown` with the remaining deadline if the child's group was already due. Also cancel already scheduled restarts when the shutdown begins (`Children.BeginShutdown`).
- **Status:** verified (a: `tests/integration/test_supervisor.py`, `tests/stress/stresskit.py` `wait_flows`; b: red, then green in `tests/fault/test_shutdown.py`, exit 5 before, exit 0 after 3.1 s)
- **Source:** `doc/PROTOCOL.md` section 5a, `src/supervisor/Children.ahk` (`Snapshot`, `BeginShutdown`), `src/supervisor/Shutdown.ahk`


### `Hub.Request`: the message must carry the registered ID

- **Problem:** The reply must find its callback via `corr`, which is the ID of the request. If the message carries a different ID than the one stored, the callback never fires, and only the timer ends the request.
- **Wrong:** Generating the ID again after it was stored in the callback directory.
- **Right:** Generate the ID once, store the callback under it, and set the same ID in the message. Start the timer after sending and stop it on completion.
- **Status:** verified (`test_answer_to_a_hub_request_reaches_its_callback_once`). A wrong ID was not provoked on purpose.
- **Note on log timing:** the stderr lines of the supervisor appear batched, not in real time (about 2 s delay at a 500 ms deadline in one test). Check the order via the replies, not via log timestamps.
- **Source:** `src/supervisor/Hub.ahk` (`Request`, `_Finish`)


### Worker: reply first, start the element via timer

- **Problem:** `cmd.worker.run` should answer `ok` at once, while the element runs afterwards. If the handler runs the element, the reply waits as long as the element.
- **Wrong:** Running the element in the handler and then `return Map()`.
- **Right:** Store the job, set `SetTimer(this._startFn, -1)`, and let the handler reply. The same for the result of a cancel (`evt.worker.done` via timer -1), so that the reply to `cmd.worker.cancel` arrives before the event.
- **Status:** verified (`tests/integration/test_worker.py`, hub capture: `res.worker.cancel` before `evt.worker.done`)
- **Source:** `src/worker/Worker.ahk` (`_CmdRun`, `_StopCurrent`)


### `DllCall("Sleep")` in a loop: messages are handled between slices

- **Problem:** A worker waited in `DllCall("Sleep", 1000)` and answered `cmd.worker.cancel` only after up to one slice: 812 ms with 1000 ms slices, 29 ms with 100 ms slices.
- **Wrong:** Assuming a long wait is blind to messages. A single `DllCall` is indeed blind, but AHK handles messages between command lines.
- **Right:** Split long waits into short steps (100 ms). The latency is then the length of the longest step.
- **Status:** verified (measurement: cancel 812 ms vs. 29 ms). The cause (message check between lines) is assumed.
- **Source:** `tests/elements/Test/Actions/Action_TestHangWorker.ahk`


### `cmd` reply later: return `Deferred.Marker()` and reply with `Peer.Reply`

- **Problem:** Storage should run file operations in a queue, not in the message path. `Peer` replies to a `cmd.*` when the handler returns, so a later reply was not possible.
- **Wrong:** Writing the file synchronously in the handler and then replying: every other message, including `sys.ping`, waits for the full file time.
- **Right:** The handler returns `Deferred.Marker()` and enqueues the request. The reply is sent later with `peer.Reply(msg, payload)`. Every error path must reply, otherwise the sender waits until its deadline. The hub has the same mechanism (`Hub.Reply(request, payload)`, used by the crash report, which must answer exactly once).
- **Status:** verified (`tests/ahk/dispatcher.test.ahk`, case "a Deferred marker is passed through"; `tests/integration/test_storage.py`)
- **Source:** `src/core/ipc/Deferred.ahk`, `src/core/ipc/Dispatcher.ahk`, `src/core/ipc/Peer.ahk`


### Atomic replace: `MoveFileExW` with flags, and flush before the rename

- **Problem:** v1 deletes the file and writes it anew (`FileDelete` + `FileAppend`); a crash in between loses the file. Also, the temp file was only closed before the rename, so after a power failure the rename could reach the disk before the data.
- **Right:** Write a temp file in the same folder (`FileOpen(tmp, "w", "UTF-8-RAW")`) and call `DllCall("FlushFileBuffers", "Ptr", file.Handle, "Int")` before `Close`; 0 means error. Then `DllCall("MoveFileExW", "Str", tmp, "Str", target, "UInt", 0x9, "Int")`: `0x9` = `MOVEFILE_REPLACE_EXISTING` (1) | `MOVEFILE_WRITE_THROUGH` (8). Read `A_LastError` directly after the call. A write-protected target makes the replace fail and the old file stays.
- **Status:** verified (`test_read_only_target_fails_with_error_event_and_keeps_the_old_file`, `test_hard_kill_during_a_big_write_...`). That the data really reaches the disk before the rename in a power failure: not checked.
- **Source:** `src/storage/AtomicFile.ahk`


### Time values are per process: `Time.NowMs` is not comparable across processes

- **Problem:** The stub should compare arrival times with timestamps from the Python test. `Time.NowMs` is a performance counter (QueryPerformanceCounter) with a zero point in each process.
- **Wrong:** Comparing `Time.NowMs()` in AHK with `time.perf_counter()` in Python.
- **Right:** Use wall-clock time via `GetSystemTimePreciseAsFileTime` (8-byte buffer): `NumGet(buf, 0, "Int64") / 10000 - 11644473600000` gives ms since 1970 UTC, the same as `time.time() * 1000` in Python. See `StubManager.WallMs`.
- **Status:** verified (probe: latencies 2 to 4 ms between command and first event)
- **Source:** `src/manager/ManagerModel.ahk` (`WallMs`)


### Log lines are lost when another process has the file open (sharing violation)

- **Problem:** Under load, log lines went missing as soon as another process (test reader, editor, virus scanner) had the log file open. The error was `OSError (32)`, and the line was lost.
- **Cause (verified):** `FileAppend` opens the file without sharing. As soon as another process holds a handle, even read access with `FILE_SHARE_READ|WRITE`, `FileAppend` fails with 32. There is no retry. `FileGetSize` and `FileExist` still work. (An earlier `OSError (6)` observation could not be reproduced; its cause is assumed to be a stale `A_LastError`.)
- **Wrong:** `FileAppend` for files that other processes may read; discarding a line on error, or retrying in a blocking loop.
- **Right:** `FileOpen(path, "a", "UTF-8-RAW")` without `-rwd` flags (shares read and write). On sharing errors (5, 32, 33), leave the operation at the head of the queue and retry via timer, so the order is kept and the message loop runs between attempts. After 3 s reply `busy` and count the lost line. One operation per file, so a retry never writes the other file twice.
- **Status:** verified (before the fix 3 of 3 runs red, 30 to 40 of 120 lines per source; after the fix 6 of 6 green, `test_no_log_line_is_lost_while_other_processes_hold_the_files`)
- **Source:** `src/storage/LogSink.ahk` (`AppendTo`), `src/storage/WriteQueue.ahk` (`RunOne`)


### Reference cycle via `ObjBindMethod(this, ...)` in a field keeps closed connections alive

- **Problem:** The supervisor grew by about 83 KB per client connection (400 connections: 25 to 58 MB) while the handle count stayed constant. `this._pollFn := ObjBindMethod(this, "Pump")` is a cycle (object → bound function → object), so a closed connection with its buffers is never released.
- **Wrong:** Checking only the handle count; closing an object that keeps bound functions of itself in its fields.
- **Right:** On close, clear the fields after the timer is switched off with `SetTimer(fn, 0)` (which needs the same function object): `this._pollFn := ""`, `this._notifyFn := ""`. Afterwards the memory stayed flat over 800 connections (17.47 to 17.49 MB). The same pattern exists in other classes (`ExecContext`, `Executor`, `WorkerBridge`, `Engine`); these were only read, not measured.
- **Status:** verified (measurement before and after the fix; the other classes: not checked for leaks)
- **Source:** `src/core/ipc/PipeConnection.ahk` (`__New`, `_NotifyClose`), `tests/stress/test_clients_churn.py`


### Log writes: batch the operations; one operation per timer run is too slow

- **Problem:** `WriteQueue` ran one operation per timer run (`SetTimer(..., -1)`, resolution about 15.6 ms), and each log line needed an open, a size query and a close: 28 lines per second. A flood of 290 events per second grew the backlog to 56 MB and kept writing for 207 s. Requests shared the queue with log lines and waited behind them.
- **Right:** Two queues (requests first). Per run a time budget (10 ms) instead of one operation. Lines per file are batched into one open and close. An upper limit with a counter.
- **Status:** verified (`tests/stress/test_log_backlog.py`: 1493 lines per second sustained; flood of 362 events per second: log complete 1 s after the end). The 10 ms budget was not compared with other values.
- **Source:** `src/storage/WriteQueue.ahk`, `src/storage/Storage.ahk`


### Check whether a PID is still alive with `OpenProcess`

- **Problem:** At start, temp files of dead processes (`*.ahf-<pid>.tmp`) should be deleted, but not those of a running process.
- **Right:** `OpenProcess(SYNCHRONIZE, 0, pid)`: handle 0 with `A_LastError` 87 (`ERROR_INVALID_PARAMETER`) means no process with this number. Other errors (e.g. 5, access denied) count as "running", so nothing is deleted on suspicion. With a handle, `WaitForSingleObject(h, 0)` returns `0x102` (WAIT_TIMEOUT) while the process runs. A reused PID can keep an old temp file alive (harmless).
- **Status:** verified for a dead and a live PID (`test_temp_files_of_dead_processes_are_removed_at_start_and_those_of_live_ones_stay`); access denied not checked.
- **Source:** `src/storage/AtomicFile.ahk`


### Heartbeat: after a standstill of the supervisor all children look hung

- **Problem:** `Heartbeat.Tick` compared `now - lastPongAt` with the pong deadline. If the supervisor itself stood still (frozen, standby, big backlog), all healthy children counted as hanging at once and were terminated. Reproduced by `psutil.suspend()` on the supervisor for 8 s.
- **Right:** Record the time of the last tick. If the gap is larger than `PING_EVERY_MS` (2 s), restart the pong, ping and start deadlines of all children from "now" (`Children.ResetLiveness`). A child that really hangs is found one pong deadline later. Arm the heartbeat at the start of the timer, so a standstill before the first tick also counts.
- **Status:** verified (freeze 8 s: `tests/fault/test_supervisor_stall.py`). Standby and whether `QueryPerformanceCounter` runs on in standby: assumed.
- **Source:** `src/supervisor/Heartbeat.ahk`, `src/supervisor/Children.ahk`


### Pipe names are machine-wide, mutexes are per Windows session

- **Problem:** With two signed-in users, the second one does not see the mutex of the first (own namespace), but wants the same pipe `ahf.<session>.hub` and fails on `FILE_FLAG_FIRST_PIPE_INSTANCE`.
- **Right:** Build the pipe name from the session ID (`ProcessIdToSessionId`) and a hash of the user SID (`PipeNames.Hub`). Name the mutex explicitly `Local\...`. A Python twin (`tests/support/pipenames.py`) builds the same name for the tests.
- **Status:** name building and "a foreign pipe with the old name does not block" verified; the second Windows user not checked (not possible in this environment).
- **Source:** `src/core/PipeNames.ahk`


### `CreateProcessW` with redirected handles instead of `Run`

- **Problem:** `Run()` starts a process without a usable stderr. Load errors, the messages of `Role.Console` and the last words before a crash were lost; the supervisor only saw the exit code.
- **Right:** Start the child with `CreateProcessW` via `DllCall`:
  - `CreatePipe` with a `SECURITY_ATTRIBUTES` (24 bytes, `bInheritHandle` at offset 16 = 1), then `SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0)`: only the write end is inherited. Use a large pipe buffer (256 KB), or the child blocks while the supervisor reads only every 200 ms.
  - `STARTUPINFOEXW` (112 bytes on 64 bit): `cb` at offset 0, `dwFlags` at 60 (`STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES`), `wShowWindow` at 64 (`SW_HIDE` = 0), `hStdInput` at 80, `hStdOutput` at 88, `hStdError` at 96, `lpAttributeList` at 104. `PROCESS_INFORMATION` (24 bytes): `hProcess` at 0, `hThread` at 8, `dwProcessId` at 16.
  - Inherit only the needed handles: `InitializeProcThreadAttributeList`, `UpdateProcThreadAttribute` with `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` (0x20002), `EXTENDED_STARTUPINFO_PRESENT` (0x80000) in the flags. Without the list the child inherits every inheritable handle of the supervisor.
  - The command line must be a writable `Buffer` (`StrPut`), because `CreateProcessW` may write into it.
  - Afterwards close `hWrite`, the NUL handle and the thread handle in the supervisor, or EOF never arrives.
  - Read without blocking: `PeekNamedPipe` for the available bytes, then `ReadFile` for exactly that many. Split lines at byte `0x0A` and only then decode UTF-8 (a character can be split across reads).
- **Pitfalls:** `NumPut("ptr", buffer, ...)` with a `Buffer` object throws "Invalid parameter(s)"; pass `buffer.Ptr`. `StrGet(address, length, "UTF-8")` takes the length in bytes.
- **Status:** verified (`tests/ahk/child_launcher.test.ahk`: stdout, stderr, NUL as stdin, exit code, 40 starts without handle growth; `tests/fault/test_diagnose.py`: 50 restarts, supervisor handles constant). Not checked: that a child really inherits no other handle (no simple way to read the handle table of another process).
- **Source:** `src/supervisor/ChildLauncher.ahk`, `src/supervisor/ChildPipe.ahk`


### Read the header of a JSON frame with one regex; check the payload only for balance

- **Problem:** The hub parsed every frame completely (220 ms for 109,232 characters), but it only needs `to` and must replace `from`.
- **Wrong:** Reading only the start and appending the rest unchecked: a second `"from"` after the payload could then be preferred by a parser ("last key wins"), and the sender would be forged.
- **Right:** One `RegExMatch` on the text in exactly the form of `Message.Serialize` (fixed field order, no whitespace). It captures the payload as a balanced object with PCRE recursion and requires the frame to end there: `(?<obj>\{(?:[^{}"]++|"(?:[^"\\]++|\\.)*+"|(?&obj))*+\})\}\z`. Possessive quantifiers prevent backtracking. If nothing matches, the caller takes the full parse path. Set the regex in `try`, because compilation errors throw. Cost: 1.3 ms for 109,232 characters.
- **Status:** verified (`tests/ahk/message.test.ahk`, cases `ParseHead`/`WithFrom`; a frame with text behind the payload is rejected). Very deep nesting (PCRE recursion limit): not checked.
- **Source:** `src/core/ipc/Message.ahk`, `src/supervisor/Hub.ahk`


### Set a child's state before `CreateProcessW`, not after

- **Problem:** `Children._Launch` set the state to `starting` only after the start. AHK can be interrupted during that time; the hub then processes messages, and a fast child reported `sys.hello` before the state was stored. `OnHello` set `ready`, and the late write of `starting` overwrote it: the child was `starting` forever.
- **Right:** Set the state before the start. After the start store only PID, handle, reader and `gone`. `OnHello` takes the PID from the link if the record does not have one.
- **Status:** verified (12 of 12 green after the fix; the race itself was not reproduced deterministically)
- **Source:** `src/supervisor/Children.ahk` (`_Launch`, `OnHello`)


### Own process data via DllCall: memory, handles and run time

- **Problem:** A status snapshot needs memory, handle count, start time and run time, without a loop and without WMI.
- **Right:** The pseudo handle `GetCurrentProcess()` (-1) is enough for all three. `psapi\GetProcessMemoryInfo(h, buf, 72)` with `cb` set to 72 beforehand (64 bit): `WorkingSetSize` as `uptr` at offset 16. `GetProcessHandleCount(h, &n)`. `GetProcessTimes(h, created, ...)`: `NumGet(created, 0, "int64")` is the creation time as FILETIME (100 ns since 1601). AHK timestamp: `DateAdd("16010101000000", ticks // 10000000, "Seconds")`; run time is `GetSystemTimeAsFileTime` minus the creation time.
- **Status:** verified (`tests/ahk/core_snapshot.test.ahk`)
- **Source:** `src/core/ProcInfo.ahk`


### Close discards the send queue: wait until the queue is flushed

- **Problem:** A role sent `sys.bye` and then called `Peer.Close()` and `ExitApp`. `Close` cancels a running write and empties the queue. Frames that did not fit into the pipe (64 KiB, hub not reading at that moment) were lost, including `sys.bye`. Reproduced with a hub that does not read for 0.6 s: 572 of 800 pongs arrived, no `sys.bye`.
- **Wrong:** `Send(...)` followed by `Close()`, assuming the frame is written. `SendFrame` returns `true` as soon as the frame is in the queue. Also wrong: `FlushFileBuffers` on the pipe, which waits without deadline if the reader stands still.
- **Right:** `PipeConnection.CloseWhenFlushed(timeoutMs, onDone)`: no new frames; a timer (10 ms) keeps writing the queue; closing happens when the queue is empty or at the deadline; `onDone(flushed)` runs exactly once, from the timer. `Peer.CloseWhenFlushed` first detaches `OnClose`, so the end does not start a reconnect. The role calls `ExitApp` in the callback and sets an emergency timer (deadline + 1 s).
- **Status:** verified (`tests/integration/test_pipe.py::test_frames_queued_when_the_connection_is_ended_reach_a_late_reader`, `tests/integration/test_role.py::test_frames_queued_at_shutdown_and_the_bye_reach_a_hub_that_reads_late`). That this caused the `clean: false` of the acceptance runs: assumed.
- **Source:** `src/core/ipc/PipeConnection.ahk`, `src/core/ipc/Peer.ahk`, `src/core/Role.ahk`


### A write error to a departed peer must not discard its unread frames

- **Problem:** A child writes `sys.bye` and ends itself. Before the hub reads that frame, the hub writes to the child (an event of a topic it subscribed to). `WriteFile` fails with 232 ("pipe is being closed"); `SendFrame` then called `_Fail` and `_Teardown`, which discarded the unread incoming bytes, including `sys.bye`.
- **Wrong:** Treating a write error as the end of the connection. The peer may have written data before its end, and that data stays readable in the pipe buffer after its handle is closed.
- **Right:** On 109, 232 or 233 from a write, close only the write side (discard the queue; `SendFrame` returns `false`) and keep reading until the read reports the end; then `peer_closed`. An upper limit (`WRITE_GONE_MAX_MS`, 1 s) covers the case where the end never comes. Other write errors still close at once.
- **Status:** verified (`tests/integration/test_pipe.py::test_frames_of_a_peer_that_has_gone_are_read_although_a_write_to_it_fails`). That this caused the rest of the `clean: false` failures: assumed.
- **Source:** `src/core/ipc/PipeConnection.ahk` (`_DriveWriteGuarded`, `_WriteSideGone`, `Pump`)


### A router must know which requests are open

- **Problem:** The hub forwarded `cmd.*` between two clients without remembering them. If the target died before replying, the sender waited its full deadline (30 s for the engine's storage read).
- **Wrong:** Relying on "every request is answered". Also rejected: letting roles detect the end via `evt.process.*`, which arrives late and is not sent at all when only a pipe breaks.
- **Right:** The hub notes the header fields of each forwarded request (sender, `id`, type, target) until the target replies or the deadline plus 1 s has passed. When the target's connection ends, it replies `peer_gone`. The connection is read to its end first, so a real reply wins. In a multi-threaded Python hub, register the request before forwarding it.
- **Status:** verified (`tests/integration/test_supervisor.py::test_open_request_to_a_*`: 10 s without reply before, 0.07 to 0.15 s after; `tests/integration/test_engine.py::test_engine_resumes_loading_at_once_when_storage_dies_with_an_open_read`)
- **Source:** `src/supervisor/Hub.ahk` (`_NoteRouted`, `_FailRouted`), `tests/support/pyhub.py`


### Deadlines via `SetTimer` do not survive a standstill: check them in the tick

- **Problem:** A deadline set with `SetTimer(fn, -ms)` runs on wall-clock time. After a standstill (frozen, standby) the timer is due at once and may run before the tick that notices the standstill. A `cmd.app.prepareExit` request with a 10 minute deadline then ended with "timeout" right after resuming.
- **Right:** Store the deadline as a point in time (`dueAt`) in the request entry and check it in the tick (`Hub.Tick`). The tick measures the standstill first (`Stall.Check`), shifts all `dueAt` values (`Hub.Shift`), and only then checks the deadlines. Accuracy is one tick (200 ms). If an early expiry is harmless, resetting the timer with the remaining time is enough.
- **Status:** verified (`tests/fault/test_supervisor_stall.py::test_open_prepare_exit_request_keeps_its_remaining_time_after_a_stand_still`: ended 0.24 s after resuming before, 5.11 s after the fix). That the timer would really run first was not reproduced.
- **Source:** `src/supervisor/Stall.ahk`, `src/supervisor/Hub.ahk`


### Do not relabel a process that has already ended

- **Problem:** `Children.KillWorker` set the state to `stopping` and the reason to `killed` before `Terminate` found that the process was already dead (the end was evaluated only at the next tick). A real crash was reported as `killed`, without a crash report.
- **Wrong:** Changing a record and only then checking whether the action is still needed.
- **Right:** Before relabeling, check `WaitForSingleObject(handle, 0)` (`Children._HasEnded`). If the process has ended, set nothing and only log; the end is then evaluated normally.
- **Status:** verified (AHK unit tests `KillOfAnEndedWorkerStaysACrash`, `EngineEndKeepsTheCrashOfAnEndedWorker`: red before, green after the fix)
- **Source:** `src/supervisor/Children.ahk`, `tests/ahk/supervisor_tick.test.ahk`


### Assign a sequence number and send it under `Critical`

- **Problem:** With 200 parallel instances, engine events arrived out of `seq` order (253 after 271). `Engine.Emit` assigned `seq` and then called `peer.Send`; a timer that interrupted in between sent its events first, and the stub discards events with a smaller `seq` as already seen.
- **Wrong:** `this.seq += 1` followed by serializing and sending, without protection.
- **Right:** `prev := Critical("On")`, assign `seq` and send, and `Critical(prev)` in a `finally`. Apply this wherever the order between numbering and sending matters.
- **Status:** verified (before the fix 2 of 2 runs with swapped order; afterwards 3 of 3 runs at the Python hub, and the 200-instance tests ran more than 100 times without swapped `seq`)
- **Source:** `src/engine/Engine.ahk` (`Emit`), `tests/stress/test_parallel_instances.py`


### Publish a state only after its fields, under `Critical`

- **Problem:** In 2 of 53 runs of the 200-instance test, an instance ended with "element Trigger_Manual cannot be an action (mode trigger)". `Scheduler.Advance` set the thread to `ready` and only a few lines later the next element. A timer interrupted in between and ran the thread with the old element.
- **Wrong:** Publishing a state (here `ready`) before the associated fields are set, in code that timers can interrupt.
- **Right:** Run the transition as a whole under `Critical` (`Executor._Advance`), or set the fields before the state change. Effect: 60 of 60 runs of the 50/200-instance test without failure.
- **Status:** cause verified by message and code (the interruption itself was not observed); fix proven statistically (60/60). Other places with the same pattern were not checked.
- **Source:** `src/engine/Executor.ahk` (`_Advance`), `src/engine/core/Scheduler.ahk` (`Advance`), `tests/stress/test_parallel_instances.py`


### Waiting for a message: `Sleep(1)` returns only at the next tick of the system timer

- **Problem:** A worker element waits blocking for the answer of the engine (WI-0050). A loop of `Sleep(1)` until the answer is there gave a round trip of 15 ms (median of 300 calls), although the answer arrives after about 1 ms: the wake-up message runs its handler during the `Sleep`, but `Sleep` itself ends only with the next tick of the system timer (15.6 ms).
- **Wrong:** `while (!done) Sleep(1)`.
- **Right:** Wait for a message, then let AHK handle what is queued: `DllCall("MsgWaitForMultipleObjectsEx", "UInt", 0, "Ptr", 0, "UInt", 50, "UInt", 0x4FF, "UInt", 0x4, "UInt")` (QS_ALLINPUT, MWMO_INPUTAVAILABLE: it also returns for a message that is already in the queue), then `Sleep(-1)`. Round trip 1.0 ms (median). The 50 ms bound keeps the loop able to check its own deadline. Only in the worker (a role that may block).
- **Status:** verified (both variants measured with `tests/integration/test_worker_vars.py`, round trip test). Not checked: a thread that is `Critical` (its messages stay in the queue, the loop would then spin until its deadline; ELEMENT-API-V2 3.2 forbids the call there).
- **Source:** `src/worker/WorkerContext.ahk` (`_WaitForMessages`)


### A blocking wait inside a callback of the peer waits for nothing

- **Problem:** The answer to a request arrives through `PipeConnection.Pump`, which has a guard against re-entry. Code that runs inside the pump (a request callback, a message handler) and then waits blocking for another answer would wait in vain: the pump that would read the answer returns at once because the outer one is still running. Only the deadline of the request ends the wait.
- **Right:** Run code that may wait on a thread of its own: `ctx.Request` of a worker element calls its callback with `SetTimer(fn, -1)`, outside the pump, so the callback may use the variable functions (which wait).
- **Status:** assumed (derived from the guard in `PipeConnection.Pump`, not reproduced)
- **Source:** `src/worker/WorkerContext.ahk` (`_OnRequestAnswer`)


### The end of a called instance goes to the caller in the next tick, not from the step that ended it

- **Problem:** A waiting `Action_Execute_Flow` must finish when the called instance ends. The end is found in `Executor._EndRun`, deep inside the step of the called instance (`_Advance`, under `Critical`). Calling the caller's `ctx.Finish` there would run the caller's step (and maybe its end, and the end of its caller ...) nested inside the other one, under `Critical`, and a chain of 100 waiting calls would nest 100 steps on the AutoHotkey stack (which ends the process at about 2000 calls, see above).
- **Right:** `_EndRun` only queues `[call, outcome]` (`Executor._notes`); `Tick` hands the outcomes over first, one by one, before it dispatches threads. Each end is a flat step; the depth of a call chain costs no stack. A call is a Map with a flag `cancelled`, so a stop of the caller (`ExecContext.CancelTimers`) also drops an outcome that is already queued, and the function reference is cleared on delivery or cancel (the bound context would otherwise be a reference cycle).
- **Status:** verified (`tests/ahk/engine_call_flow.test.ahk`, cases of the depth limit and of the stopped caller; `tests/integration/test_core_d_flows.py::test_waiting_calls_of_a_flow_to_itself_are_limited`)
- **Source:** `src/engine/Executor.ahk` (`CallFlow`, `_EndRun`, `_Deliver`)


### Take a shared entry with one `Delete`, not with `Get` and then `Delete`

- **Problem:** `WorkerBridge` read a job with `Get`, checked it, and removed it with `Delete` in a later line. The deadline timer of the same job could run between the two lines and get the same record: the job ended twice (`onDone` called twice) or the `Delete` threw `Item has no value` in the other thread. Reproduced by a probe with a 1 ms deadline (5 double callbacks and 11 throws in 199,458 jobs before the fix, 0 in 234,140 after).
- **Wrong:** `jobRec := m.Get(k, ""); if (IsObject(jobRec)) { m.Delete(k); Call(jobRec) }` in two threads.
- **Right:** `try jobRec := m.Delete(k)` and `catch return ""`: `Delete` returns the removed record and throws when it is gone, and the builtin call is not interrupted. Only the caller that gets the record acts on it.
- **Status:** verified (`tests/ahk/engine_worker_bridge.test.ahk`, `AnswerAndDeadlineOfOneJobEndTheJobOnce`, red before with `expected 1 but got 2`, green after; the probe above)
- **Source:** `src/engine/WorkerBridge.ahk` (`_TakeJob`), `doc/OPEN-ITEMS.md` F-0012


### A race test must hook the access the fixed code makes, not the old one

- **Problem:** The first race test for `Executor` hooked `Has` on the active-thread map, the check of the old code. After the fix (one `Delete` with `try`, no `Has`) the hook never ran: the stop counts of the test were wrong (0 and 1), and the first draft of the test showed nothing about the fix.
- **Wrong:** A spy that runs the other path inside one specific method (`Has`, `Get`) of the old code.
- **Right:** Hook the access that is the take in the fixed code (here `Delete`), and run the other path just before the real access. Check that the test is red on the old code and green on the fix; a test that is green on both proves nothing.
- **Status:** verified (`tests/ahk/engine_executor.test.ahk`: the `Delete` spy is red on the old code (`Item has no value.`) and green on the fix)
- **Source:** `tests/ahk/engine_executor.test.ahk` (`SpyActive`), `src/engine/Executor.ahk` (`_OnFinish`, `_StopRun`), `doc/OPEN-ITEMS.md` F-0012


### An event of a trigger can arrive before the answer that arms it

- **Problem:** A trigger that fires in its `Enable` sends its event before the trigger host answers the `cmd.trigger.arm`. The engine still had the trigger as not armed, so the event was dropped and no instance started (the startup trigger never fired in the first run of the e2e test).
- **Wrong:** Accept an event only when the arm is confirmed (`armed` set by the answer).
- **Right:** Count an arm on its way as accepted for its own generation: the entry keeps `sent` from the send until the answer. A refused arm clears it again. The instances that such an event started run on (as v1 would start them).
- **Status:** verified (`tests/integration/test_trigger_arming.py::test_the_startup_trigger_fires_once_at_the_start_of_autohotflow` was red without the fix, `tests/ahk/engine_trigger_arms.test.ahk` covers `Accepts` before and after the answer)
- **Source:** `src/engine/TriggerArms.ahk` (`Accepts`, `_StartArm`, `_OnArm`), `src/triggerhost/TriggerHost.ahk` (`_CmdArm`)

### An error in a request callback ends that request, the step after it never runs

- **Problem:** `Peer._Finish` runs the callback of a request in a `try`. An exception there is only written as an `a0` line (`callback for <type> failed`) and the request counts as finished. A start that waits in such a callback then never reaches its next step: `evt.engine.ready` does not come, and the test reports only the timeout.
- **Wrong:** Reading only the test output when a start times out.
- **Right:** When a start times out, first read the `a0` lines of the engine's log (`callback for` and the exception text), then the callback that is named there. Keep callbacks short and guard every `Delete` (see the entry about `Map.Delete`).
- **Status:** verified (`src/core/ipc/Peer.ahk` read). Not verified: the `a0` line itself; the WI-0068 hang was found by reading the code, the test output showed only the timeout.
- **Source:** `src/core/ipc/Peer.ahk` (`_Finish`), `src/engine/FlowStateFile.ahk`

### Reading the end of a log file that other processes append to

- **Problem:** The tail of `Log.txt` (WI-0080) must be read while storage appends to it, and the file can be bigger than the part that is wanted. `File.Read(n)` counts characters, not bytes, so the byte count of the end is wrong with UTF-8.
- **Wrong:** `FileOpen(path, "r")`, `file.Pos := start` and `file.Read(count)` for a byte count: the read is off in every file with umlauts.
- **Right:** Read bytes into a `Buffer` with `file.RawRead(buf, count)` (`count` = bytes), decode with `StrGet(buf.Ptr, count, "UTF-8")`, and drop the first line when the read did not start at the beginning. Open with `"r"` only: the writers hold their own handles, and a plain `FileOpen` does not deny them (LogSink comment).
- **Status:** verified for ASCII text (`tests/integration/test_storage.py::test_log_tail_*`). Assumed for the byte count with umlauts (not run, no test with non-ASCII text yet).
- **Source:** `src/storage/LogSink.ahk` (`Tail`)

### A ListView that follows a growing list keeps the row numbers of the model

- **Problem:** A log of 1000 entries redrawn on every change rebuilds 1000 rows per burst line. Only the rows that are new or that fell out of the front are wanted.
- **Right:** Each entry carries its number `n` from the model. The view keeps the list of the `n` it shows: rows below the first visible `n` are removed with `lv.Delete(1)` at the front, rows above the last shown `n` are added with `lv.Add` at the end. Any change of the filter rebuilds the list. The row removal and the addition run between `Opt("-Redraw")` and `Opt("+Redraw")`.
- **Status:** assumed (the logic is in `src/manager/LogWindow.ahk`; the window was not run by the agents, `gui` tier is for the owner)
- **Source:** `src/manager/LogWindow.ahk` (`_Update`, `_Rebuild`)

