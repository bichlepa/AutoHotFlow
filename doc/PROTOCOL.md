# Protocol AutoHotFlow v2 (IPC)

Status: draft, protocol version **1**. Rationale for the technology: [ARCHITECTURE.md](ARCHITECTURE.md), section 2.2.

---

## 1. Transport

- **Hub:** The supervisor operates the pipe `\\.\pipe\ahf.s<winSession>.u<tag>.<session>.hub` (name from `PipeNames.Hub`, `src/core/PipeNames.ahk`; `<winSession>` is the Windows session ID from `ProcessIdToSessionId`, `<tag>` is 8 hex digits of the FNV-1a hash of the user SID, e.g. `ahf.s1.u1a2b3c4d.main.hub`). The roles do not build the name themselves; they receive it with `--hub=<name>`. Reason (WI-0022): pipe names are valid for the whole machine, mutexes only per Windows session. With a second logged-on user (fast user switching, terminal server), the second instance did not find the mutex, wanted to serve the same pipe name and failed with exit 1. Tests use `tests/support/pipenames.py` (`hub_pipe(session)`). All other roles connect as clients. There are no direct connections between non-hub processes.
- **Session (`<session>`):** The default is `main` (option `--session=<id>`, default `main`). Deviation from the originally planned choice (supervisor PID and start time): a second instance must find the running hub in order to submit its command (section 4.1, `cmd.app.command`). With PID and start time it would not know the name. The single-instance lock (named mutex `Local\AHF.supervisor.<session>`, explicitly in the namespace of the Windows session, `PipeNames.Mutex`) and the pipe use the same key `<session>`. Several parallel sessions (e.g. tests) get their own `--session` values.
- **Pipe:** Byte mode, duplex, `FILE_FLAG_OVERLAPPED`, `PIPE_REJECT_REMOTE_CLIENTS`, one server instance per client (the hub creates a new instance after each `Connect`).
- **Frame:** `uint32` length (little endian) + UTF-8 JSON. Maximum size 16 MiB. Larger payloads (e.g. large flows) are split via `storage` files or chunking (`seq/total` in the payload), not via a larger frame.
- **Wake-up call:** After each write, the sender sends `PostMessage(peerHwnd, 0x8001, 0, 0)` (`WM_AHF_WAKE`). The receiver reads on the wake-up call and additionally via a fallback timer (250 ms). A client that knows the hub HWND (peer option `hubHwnd`) wakes the hub already with `sys.hello` (section 5); without the wake-up call the hub only accepts the new client after up to 250 ms.
- **Delivery:** Order per connection is preserved, at most once, no persistence. Lost messages are handled via timeouts and resync (section 5), not via retransmission.
- **Encoding:** JSON numbers are numbers, strings are strings. Flow data keep the types of the file (e.g. `"zoomFactor": "0.700000"` stays a string).

## 2. Envelope

Every message is a JSON object with a fixed schema. The serializer writes the header fields **first, in this order**, so that the hub can read `to` without fully parsing the payload.

```json
{
  "to": "engine",
  "from": "editor:Flow 1010290492",
  "id": "editor:Flow 1010290492#17",
  "type": "cmd.flow.start",
  "corr": null,
  "timeoutMs": 5000,
  "payload": { "flowId": "Flow 1010290492" }
}
```

| Field | Type | Meaning |
|---|---|---|
| `to` | string | Role address (see 3) or topic `topic:<name>` for events. `"*"` only for `sys.*` broadcasts from the supervisor. |
| `from` | string | Sender role address. The hub sets it based on the connection and overwrites wrong values. |
| `id` | string | `<from>#<n>`, `n` is a counter per process and session (not `A_TickCount`). |
| `type` | string | See prefixes below. |
| `corr` | string or null | For responses, the `id` of the request. |
| `timeoutMs` | int or absent | Only for `cmd.*`, deadline after which the sender treats the request as failed. Default 5000, `storage` operations 30000. |
| `payload` | object | Type-specific (section 4). Always an object, never `null`. |

**Type prefixes**

| Prefix | Meaning | Response expected |
|---|---|---|
| `cmd.` | Command or request | yes, exactly one `res.` with `corr` (unless marked as `noReply`) |
| `res.` | Response to `cmd.`, type is `res.<cmdtype without "cmd.">` | – |
| `evt.` | Event, distributed to subscribers of the topic | no |
| `sys.` | Lifecycle (hello, ping, shutdown) | depends on type |

**Response:** `payload` contains `{ "ok": true, ...data }` or `{ "ok": false, "error": { "code": "...", "message": "..." } }`.

**Deferred response (WI-0012):** A `cmd.` handler may return `Deferred.Marker()` and send the response later with `peer.Reply(request, payload)`. As long as the handler returns the marker, the peer sends nothing. The handler is then responsible for exactly one `Reply`, also on every error path (otherwise the sender ends with its timeout). Used by `storage` (queue, section 4.6). Implemented in `src/core/ipc/Deferred.ahk`, `Dispatcher.ahk`, `Peer.ahk`.

**Error codes:** `timeout`, `unknown_type`, `bad_payload`, `not_found`, `conflict` (revision), `busy`, `denied`, `internal`, `peer_gone`, `shutting_down`, `gone` (the execution or instance that a request names has ended or was stopped, WI-0050, section 4.5).

**Forwarding in the hub (WI-0024):** For frames from connected clients, the hub reads only the header fields (`Message.ParseHead`) and forwards the payload unchanged as text. It only replaces `from` (`Message.WithFrom`). This applies to frames **in exactly the form that `Message.Serialize` writes**: header fields in the order `to, from, id, type, corr, [timeoutMs,] payload`, no whitespace, `payload` an object, after the object only the closing `}`. Anything else (whitespace, different order, missing `corr`, payload not an object, text after the payload) goes through the full path (`Message.Parse`, new `Message`, `Serialize`) as before and is checked there. Messages to `supervisor` are always parsed fully. Measured: a 93 KB frame costs 1.7 ms in the hub instead of 220 ms. Consequence: the hub no longer checks the **content** of the payload (it only counts brackets and strings). The receiver rejects an invalid payload (`Peer._RejectFrame`): if the envelope is readable JSON, it answers a `cmd.` with `bad_payload`, otherwise the frame is discarded and counted (`badFrames`). A sender whose payload is not even JSON receives no response, as before (only its own timeout), because even the full path cannot read `from` and `id` in that case.

**Requirement for every receiver:** every `cmd.` request is answered (also with an error). On deadline expiry the sender itself creates a local `res.` with `timeout` and discards later responses with an unknown `corr`. If the envelope is invalid but `from`/`id`/`type` are readable, the receiver answers with `bad_payload`. Completely unreadable frames are discarded and counted.

**Target lost before the response (WI-0034, F-0036):** The hub remembers every `cmd.` request that it forwards from one client to another (header fields only: sender, `id`, `type`, target), until the response (`res.` with this `corr`, from the target of the request) arrives back, or the deadline of the request (`timeoutMs`, default 30000 if not given) plus 1000 ms has passed. If the connection of the target ends earlier (process ended or crashed, pipe broken, queue overflow, reconnection under the same name), the hub immediately answers the sender for every open request with `res.<type>` `{ ok: false, error: { code: "peer_gone" } }` (`from` is `supervisor`). The connection is read to its end beforehand: a response that the target wrote before its end arrives first, and no second one follows. On a reconnection the real response may still arrive after the `peer_gone`; the sender discards it as an unknown `corr` (`lateReplies`). `peer_gone` therefore means "outcome unknown": a sender that repeats a write request must reckon with double execution. Requests to `supervisor` and the hub's own requests (`Hub.Request`) are not affected, they have their own path. Previously the sender waited until its deadline (the engine 30 s when loading).

**Boolean values (WI-0026, E0008):** On the wire, boolean values are JSON `true`/`false`, never `1`/`0`. This applies to all fields in this document that are called `bool` or are boolean values such as `ok`, `cancel`, `started`, `clean`, `restart`, `enabled`, `executing`, `exists`, `existed`, `waiting`, `byMeta`, `delete`, `busy`, `truncated`, `hidden`, `accepted`, `withValues`, `convertObjects`. The rule in three parts:
- **Writing:** `Json.True`, `Json.False` and `Json.Bool(x)` (`src/core/Json.ahk`) create the values, **only when building the message immediately before sending**. AHK v2 has no boolean type, every object is true, so `Json.False` is true in an `if`. Program state and return values therefore remain `1`/`0`. There is one exception to "when building" for `ok`: the code keeps setting `ok` internally as `1`/`0` (`Dispatcher`, `WriteQueue`, `Map("ok", true)`), and `Message.Serialize` converts the field `ok` of the payload (top level, on a copy) into `true`/`false`. This covers `Peer.Send`/`Peer.Reply`, the hub's responses and `sys.welcome`, because everything goes through `Serialize`.
- **Reading:** `Json.Parse` returns `true` as `1` and `false` as `0`, so that `if payload["ok"]` works in AHK. Receivers are tolerant: `1`/`0` and `true`/`false` count as equal (older and foreign clients).
- **The hub** passes the payload through as text (`Message.ParseHead`/`WithFrom`, see above) and does not change boolean values. A value that reaches the hub as `true` comes out as `true`.
- **Round trip:** `Parse` and `Stringify` do not preserve boolean values with exact types (`true` comes back as `1`). Anyone who forwards a parsed payload (example `StubManager._WireAnswer`) sets the boolean fields again with `Json.Bool`. Flow and variable files do not change their format (checkbox parameters remain numbers); they contain no `true`/`false`.
- **Check:** Python test peers report every received protocol field from this list that is not a JSON boolean (`tests/support/wirebool.py`, automatically in every test). The `tools/arch_check.py` rule `wire-bool` reports literals such as `"enabled", true` or `"cancel", 1` in `Map(...)`.

## 3. Addresses and Topics

| Address | Role |
|---|---|
| `supervisor` | Supervisor (hub, answers `sys.*`, `cmd.app.*` itself) |
| `engine` | Engine |
| `storage` | Storage |
| `triggerhost` | Trigger host |
| `manager` | Manager |
| `debug` | Debug window (WI-0028, 4.9) |
| `editor:<flowId>` | Editor of the flow `<flowId>` |
| `worker:<n>` | Worker, `n` assigned by the supervisor (`cmd.process.spawn`, 4.1) |

**Topics** (subscription via `cmd.topic.subscribe {topic}` to `supervisor`, renewed on reconnection):

| Topic | Content | Typical subscribers |
|---|---|---|
| `engine` | `evt.engine.*`, `evt.flow.list.changed`, `evt.settings.changed` | all UIs |
| `flow:<flowId>` | `evt.flow.*`, `evt.element.state`, `evt.connection.state`, `evt.instance.*` for this flow | `editor:<flowId>`, `manager` |
| `log` | `evt.log.entry` | `manager` (log window) |
| `process` | `evt.process.*` (fields see 4.1a), `evt.app.exitCancelled` | `manager`, tests |
| `debug` | `evt.debug.dump` (values that code outputs with `Debug.Dump`, 4.9) | `debug` (debug window), tests |

## 4. Message Catalog

All payloads are objects. `flowId`, `elementId`, `connectionId` are the identifiers from the flow files (e.g. `Flow 1010290492`, `element0000000001`).

**Implementation status at the end of Phase 2 (WI-0017, comparison with `src/`, verified by searching the type names in the source code):** All message types that `src/` sends or registers are in this catalog. Conversely, the following types of the catalog are **not yet implemented** (draft for Phase 3 or later). A client must not rely on them yet:

| Area | Not yet implemented |
|---|---|
| 4.2 Engine commands | `cmd.flow.create`, `cmd.flow.delete`, `cmd.flow.meta.update`, `cmd.flow.save`, `cmd.trigger.enable`, `cmd.trigger.disable`, `cmd.category.*`, `cmd.settings.get/set` |
| 4.3 Engine events | `evt.flow.committed`, `evt.flow.saved`, `evt.connection.state`, `evt.settings.changed` |
| 4.4 Engine ↔ trigger host | all (`cmd.trigger.arm`, `cmd.trigger.disarm`, `evt.trigger.fired`, `evt.trigger.error`); the trigger host (WI-0014, optional) is not built, the role `triggerhost` is a placeholder |
| 4.6 | `cmd.storage.settings.get/set` (already listed there as "not yet implemented") |
| 4.7 Dialogs | `evt.ui.notice`, `cmd.ui.confirmDeleteFlowFile` |

`cmd.flow.patch` is implemented, but only knows the schema and the revision check (the operations themselves come in Phase 3, see 4.2). The role `editor` is a placeholder (exit 3), `manager` exists only as a stub (`--ui=stub`, 4.8).

### 4.1 Lifecycle (`sys.*`)

| Type | From → To | Payload | Response / effect |
|---|---|---|---|
| `sys.hello` | role → supervisor | `{ name, pid, hwnd, protocol: 1, epoch? }` | `sys.welcome` |
| `sys.welcome` | supervisor → role | `{ session, peers: { name: { hwnd } }, settingsRev }` | role is `ready` |
| `sys.ping` | supervisor → role | `{ n }` | `sys.pong {n}` within 1 s |
| `sys.pong` | role → supervisor | `{ n }` | – |
| `sys.shutdown` | supervisor → all | `{ reason: "user"/"logoff"/"crash", deadlineMs }` | role cleans up, sends `sys.bye`, terminates |
| `sys.bye` | role → supervisor | `{ clean: bool }` | – (no response). The last message of the role: everything it sent before is in front of it on the same connection and arrives before it. Afterwards the role closes its connection only when its send queue has been written (`Peer.CloseWhenFlushed`), at the latest after the rest of `deadlineMs`, at most 1000 ms, and terminates (WI-0030, ARCHITECTURE 6.3) |
| `sys.busy` | worker → supervisor | `{ busy: bool }` | – (no response). The worker reports the start (`true`) and end (`false`) of a job (WI-0027, ARCHITECTURE 6.4). While `busy` is true, the supervisor sends no ping to the worker and does not evaluate any pong; at the end the pong times restart. Messages from a role other than `worker:*` are discarded (log `a0`) |
| `cmd.app.prepareExit` | supervisor → editor/manager | `{}` | `res: { ok, cancel: bool }` (user can cancel). Deadline: 600000 ms (10 minutes, `Shutdown.PREPARE_LIMIT_MS`). On expiry, synthetic response `{ ok: false, error: { code: "timeout" } }`, which counts as "no cancel"; the exit continues. A later real response is discarded (`droppedAnswers`). If the supervisor stands still during the deadline (frozen, standby), the deadline is extended by the duration of the standstill (WI-0033, ARCHITECTURE 6.2); the deadline is checked by the supervisor's tick and is accurate to one tick (200 ms). This phase has no hard deadline (ARCHITECTURE 6.3); the upper limit only prevents a request from never ending |
| `cmd.app.exit` | any UI → supervisor | `{ deadlineMs? }` (optional, integer 100 to 60000, otherwise default `--deadline`, 5000) | starts the exit (6.3), `res: { ok, started: bool }`; `started` is false if an exit is already running |
| `cmd.app.command` | second instance → supervisor | `{ argv: [...] }` (array of strings, command-line words; the instance passes `--command=<text>` as `argv` with one entry) | `res: { ok, command?, started? }`. Known command (since WI-0028): `debug` starts the role `debug` if it is not running (`started` true), otherwise it brings its window to the front (`evt.debug.show`, `started` false); the response names `command: "debug"`. Without `--command` (a plain second start, `argv` empty) the supervisor asks the manager to show its window (`cmd.manager.show`, 4.8; F-0074) and starts the manager first if it is not running and a start is allowed; the response is `{ ok }` in every case. Anything else is only logged (`a1`), the response is `{ ok }`. The second instance terminates with exit 0 (delivered) or 1 (no response, error) |
| `cmd.process.list` | any role → supervisor | `{}` | `res: { ok, processes: [ {name, role, state, pid, restarts} ] }`. Snapshot of all children, states according to ARCHITECTURE 5.3. Serves as resync for late joiners (section 5a) |
| `cmd.process.spawn` | engine → supervisor | `{ role: "worker" }` | `res: { ok, name }`, `name` is `worker:<n>` (the supervisor assigns `n`, ascending, never duplicated within a session). The process starts like every child (`evt.process.started`, on `sys.hello` `evt.process.ready`). Errors: `denied` (sender not `engine`, or `role` not `worker`), `shutting_down` (exit running), `busy` (already 16 live workers, `Children.WORKER_LIMIT`), `bad_payload` (`role` missing), `internal` (start failed). WI-0027 |
| `cmd.process.kill` | engine → supervisor | `{ name, reason }` | `res: { ok }`. `TerminateProcess` of the child `name`. Only for names `worker:<n>`, only from sender `engine`, otherwise `denied` (also for `storage`, `engine`, `manager`). Unknown name: `not_found`. A worker that has already ended: `ok` (equivalent). If the process has already ended but its end has not yet been evaluated (the request arrives between death and the next tick), it is not relabeled as planned: its end counts as its own and is evaluated normally, usually `evt.process.crashed` (F-0042, WI-0035). Otherwise the end is reported like any other, but as planned: `evt.process.exited {name, pid, clean: false, exitCode, reason: "killed"}`, no `crashed`, no restart. The termination does not count for the exit code 5 of the supervisor. `reason` (text, at most 200 characters) appears in the log `a1`. WI-0027 |
| `cmd.topic.subscribe` / `cmd.topic.unsubscribe` | role → supervisor | `{ topic }` | `res: { ok }` |
| `evt.app.exitCancelled` | supervisor → topic `process` | `{ by }` (role that cancelled) | – (exit cancelled, nothing was stopped) |

**Starting a role (D0012, E0041):** the supervisor starts a child with `AutoHotkey64.exe /ErrorStdOut=UTF-8 "<entry folder>\<role>.ahk" --role=<name> --session=<id> --hub=<pipe> --data="<dir>" --hubHwnd=<n> [--flow=<id>] [--test-roles] [--restarted=<n>] <role options>`. The entry folder is `entry\` next to the script of the supervisor; with `--test-roles` a role is also looked up in `entry\test\`. No entry file for the role (or a name that is not a plain identifier): `Spawn` fails with `bad_args`, "unknown role". The entry script of a role registers only that role, so `--role=<other>` ends with exit 2 and "unknown role". The options and messages are unchanged; only the script that carries them is a different file per role.

**Exit codes of the supervisor** (`AutoHotFlow.ahk`, `--role=supervisor` or no `--role`):
0 clean (every child has terminated itself), 1 start failed (e.g. mutex, invalid options), 5 at least one child was terminated after deadline or hang (`TerminateProcess`). The same numbers appear in the entry point (`src/AutoHotFlow.ahk`). The second instance uses 0 and 1 (see `cmd.app.command`).

**Exit codes of a running role** (`Role`): 0 clean end after `sys.shutdown`, 3 role not implemented, 4 hub lost (orphan guard or peer closed), 6 too many unhandled errors (4.1c). The supervisor writes the meaning of known codes into the log line of the crash (`Children.EXIT_TEXT`).

**Exit codes of the entry point before the role starts** (apply to every role and to the supervisor, WI-0022): 2 the interpreter is not 64 bit (`A_PtrSize != 8`, decision E0004; message on stderr: "AutoHotFlow v2 needs the 64-bit AutoHotkey v2 interpreter"; the same 2 as for invalid options or unknown role), 1 an error when loading the files before `AhfMain` runs (e.g. an element file whose `ElementRegistry.Register` throws; message on stderr, no dialog). Both checks are in the entry point before all `#Include` lines.

### 4.1a Process events (topic `process`, supervisor → subscribers)

Each entry carries `name` (the name under which the child was started, e.g. `engine`, `echo:a`) and `pid`, where the process is known.

| Type | Payload | Meaning |
|---|---|---|
| `evt.process.started` | `{ name, role, pid }` | process started, not yet ready |
| `evt.process.ready` | `{ name, pid }` | `sys.hello` arrived, role reports ready |
| `evt.process.hung` | `{ name, reason }` | no pong (3 pings × 2 s) or no `sys.hello` within 10 s. The supervisor sends `sys.shutdown` with `deadlineMs` 2000, after 2 s `TerminateProcess` |
| `evt.process.crashed` | `{ name, pid, reason: "exited"/"hung", exitCode, restart: bool }` | unexpected end (also after a hang). `restart` true if a restart is performed |
| `evt.process.exited` | `{ name, pid, clean: bool, exitCode, reason? }` | end after request (termination). `reason` is only set for a planned end of a worker: `"killed"` for `cmd.process.kill`, `"engine gone"` if the supervisor terminated the live `worker:*` because the engine ended (E0010, WI-0033; no `crashed`, does not count for exit code 5, no restart). The fields `clean` and `exitCode` apply since WI-0022/23 (not listed here before) |
| `evt.process.restarted` | `{ name, attempt }` | restart according to policy (automatic only for `storage` and `engine`; with `--test-roles` additionally `crasher`) |

**Timing of `evt.process.exited` and `evt.process.crashed` (WI-0030):** The supervisor reports the end of a process only when it has read the connection of that process to its end (a `sys.bye` has then been processed safely and `clean` is correct), at the latest 500 ms after the process end (`Children.EXIT_GRACE_MS`; for a child without a connection immediately). The message can therefore arrive up to 500 ms after the process end; normally it arrives in the same tick (200 ms).

**Voluntary exit (WI-0028):** If a child terminates itself with `sys.bye {clean: true}` and exit code 0, without the supervisor having asked it to (the debug window that the user closes), the supervisor reports `evt.process.exited {clean: true}` instead of `evt.process.crashed`. A hung child (`hung`) is still always reported as `crashed`.

Restart policy: at most 3 restarts in 60 s, otherwise the process remains `crashed` (`restart: false`). `manager` and `editor` are never restarted automatically.

### 4.1b Test roles (only with `--test-roles`)

The roles `echo`, `crasher`, `hanger`, `slow_shutdown` (sources in `tests/integration/helpers/`) are compiled only into the test entries (WI-0029, WI-0047-PREP): `tests/integration/helpers/AutoHotFlowTest.ahk` (supervisor, and every role in one process for a direct start) and `tests/integration/helpers/entry/test/<role>.ahk` (the entry of each test role, which the supervisor of the test entry starts with `--test-roles`). They are registered there only with `--test-roles`. In the product entry scripts and without the flag, their name is unknown (exit 2). Additional messages of the test roles:
- `cmd.test.arm` to `crasher` (`{}`, `res: { ok }`): starts a timer (300 ms), after which `crasher` terminates itself with `TerminateProcess` (exit 7), without `sys.bye`. The arm step allows the test to observe the process before it dies (test scenario for `evt.process.crashed`). Without arm, `crasher` does nothing.
- `cmd.test.echo`, `cmd.test.log`, `cmd.test.logstate`, `cmd.test.setlogtarget`, `cmd.test.throwlater` (`echo`): see `tests/integration/helpers/EchoRole.ahk`.
- Option `--prepare-limit=<ms>` (only with `--test-roles`, 100 to 600000): lowers the deadline of `cmd.app.prepareExit`, so that the timeout test runs in seconds. Without the flag the constant applies.
- Option `--restart-max=<n>` (only with `--test-roles`): number of automatic restarts per 60 s instead of 3, so that a test can restart a child 50 times (handle leak test).
- Option `--worker-limit=<n>` (only with `--test-roles`, 1 to 16): maximum number of live workers instead of 16, so that the test of `cmd.process.spawn` (`busy`) does not need 17 processes.
- `echo` (WI-0028): `cmd.test.dump {title, value}` calls `Debug.Dump` (4.9).
- `echo` (WI-0023): `cmd.test.stderr {text}` writes one line to stderr; `cmd.test.log {count, level, text}` writes `count` entries (default `a1`); `cmd.test.throwlater {count}` throws `count` errors from timers.

### 4.1c Unhandled errors (`evt.diag.error`, WI-0023)

| Type | From → To | Payload | Effect |
|---|---|---|---|
| `evt.diag.error` (`noReply`) | role → supervisor | `{ name, errorType, message, file, line, stack, mode }` | The supervisor writes an `a0` entry (source `diag`, text `unhandled <errorType> in <name>: <message> (<file>, line <line>, <mode>)`) and keeps the last 50 reports completely in memory (`DiagLog.Errors()`, basis of the crash report, WI-0028). |

It is sent by `Role._OnUnexpected` for every error that no `try/catch` caught (`OnError`), before the hook `OnUnexpectedError` runs. `name` is the role name (`echo:a`), `errorType` the AHK type (`ValueError`), `file`/`line` the location, `stack` the call stack (`Error.Stack`, truncated to 4000 characters), `mode` the kind of error according to `OnError` (`Return`, `Exit`, `ExitApp`). Missing fields are empty. If the peer is not connected, the message is lost (the error is in the log of the role). The supervisor counts its own unhandled errors in the same ring (sender `supervisor`).

**Threshold:** More than 20 unhandled errors within 60 seconds (`Role.ERROR_LIMIT`, `Role.ERROR_WINDOW_MS`) terminate the role with exit code **6** (`Role.EXIT_TOO_MANY_ERRORS`, "too many unexpected errors"); the message is on stderr and reaches the log via the output of the child. 20 per minute is generous: a healthy role has none, a broken element or a timer may throw a few times in a row; 21 means the state of the role is broken, a restart is better than a zombie. The window prevents rare errors from adding up over a long lifetime. For `engine` and `storage` the normal restart rule then applies (4.1a: at most 3 restarts in 60 s); other roles are reported as crashed (`evt.process.crashed`, `exitCode` 6).

### 4.2 Engine commands (clients → `engine`)

| Type | Payload | Response (`payload`) |
|---|---|---|
| `cmd.engine.snapshot` | `{ topics?: [..] }` | `{ ok, epoch, seq, flows: [ {flowId,name,category,enabled,executing,rev} ], settings, ready }` |
| `cmd.flow.get` | `{ flowId }` | `{ ok, rev, definition }` (structure like the flow file, section 7 of the architecture, without the editor's view data) |
| `cmd.flow.create` | `{ name, category?, definition? }` | `{ ok, flowId }` |
| `cmd.flow.delete` | `{ flowId }` | `{ ok }` |
| `cmd.flow.meta.update` | `{ flowId, name?, category? }` | `{ ok, rev }` |
| `cmd.flow.patch` | `{ flowId, baseRev, ops: [ ... ] }` | `{ ok, rev }` or `error.code = "conflict"` with `{ rev, definition }` |
| `cmd.flow.save` | `{ flowId }` | `{ ok, savedRev }` after `storage` acknowledgement |
| `cmd.flow.start` | `{ flowId, triggerId? }` | `{ ok, instanceId }`, with policy `wait` and a running flow `{ ok, instanceId, waiting: true }` (the instance is queued), or `error.code = "busy"` (policy `skip`) |
| `cmd.flow.stop` | `{ flowId }` | `{ ok }` (stop initiated, completion via `evt.instance.ended`). Ends running **and** waiting instances |
| `cmd.flow.toggle` | `{ flowId }` | `{ ok, action: "started"/"stopped" }` |
| `cmd.flow.enable` / `cmd.flow.disable` | `{ flowId }` | `{ ok }` (switches all triggers) |
| `cmd.trigger.enable` / `cmd.trigger.disable` | `{ flowId, elementId }` | `{ ok, message? }` |
| `cmd.category.*`, `cmd.settings.get/set` | see Phase 3 | – |

**Patch operations (`ops`)** (Phase 2 only defines the schema, Phase 3 fills it):
`{ op: "element.add"/"element.update"/"element.remove"/"connection.add"/"connection.remove"/"flow.settings", ... }`. Each operation carries the minimally required fields; order is essential.

### 4.3 Engine events (`evt.*`, engine → topics)

Each event carries `seq` (increasing per engine epoch) and `epoch`.

| Type | Topic | Payload |
|---|---|---|
| `evt.engine.ready` | `engine` | `{ epoch }` |
| `evt.engine.restarted` | `engine` | `{ epoch }` (additionally `seq`) → clients run `cmd.engine.snapshot`. Sent by the engine itself, only after a restart by the supervisor (option `--restarted=<n>`), not at the first start |
| `evt.flow.list.changed` | `engine` | `{ added: [..], removed: [..], changed: [..] }` |
| `evt.flow.state` | `flow:<id>` | `{ flowId, enabled, executing }` |
| `evt.flow.committed` | `flow:<id>` | `{ flowId, rev, byMeta: bool }` (for the editor after a rename in the manager) |
| `evt.flow.saved` | `flow:<id>` | `{ flowId, savedRev }` |
| `evt.element.state` | `flow:<id>` | `{ flowId, elementId, state: "idle"/"running"/"finished"/"exception", countRuns, lastRun }` |
| `evt.connection.state` | `flow:<id>` | `{ flowId, connectionId, state }` |
| `evt.instance.queued` | `flow:<id>` | `{ flowId, instanceId, position }` (policy `wait`: the instance waits, `position` from 1 in the queue of the flow) |
| `evt.instance.started` / `evt.instance.ended` | `flow:<id>` | `{ flowId, instanceId, reason? }`. For a waiting instance, `started` comes only at the transition to `running` |
| `evt.settings.changed` | `engine` | `{ settings }` |
| `evt.log.entry` | `log` | `{ ts, level, source, flowId?, text }` (engine/storage send log via 4.5, not here) |
| `evt.storage.error` | `engine` | `{ op, path, code, message }` (WI-0012: `op` = name of the storage operation, section 4.6; `code` = error code of the response). Only for real errors: if `storage` is missing at start or unreachable during loading, the engine sends no `evt.storage.error`, it waits (ARCHITECTURE 6.1, WI-0031) |

**Implementation in WI-0010 (`src/engine/`, Phase 2):**
- Every `evt.*` of the engine carries `epoch` (start time of the engine process, UTC with milliseconds, as an integer) and `seq` (a counter per engine process, +1 per event).
- `evt.engine.ready` with `{}` only after loading the flow list. During loading additionally `evt.flow.list.changed` `{added, removed: [], changed: []}`.
- `evt.storage.error` with `op` = `flows.list` (list failed, for a reason other than "`storage` missing" or "does not respond"; is retried without upper limit with increasing pause), `flow.read` (file not readable) or `flow.parse` (content invalid). The start is not blocked by this. A missing or non-responding `storage` (`not_found` with "no peer ...", `timeout`, `peer_gone`, `shutting_down`) is not an error of this kind (WI-0031).
- **Start of the engine (WI-0031):** The engine always subscribes to the topic `process` (not only with the worker pool), queries `cmd.process.list`, and begins loading when `storage` has the state `ready` or `evt.process.ready` `{name: "storage"}` arrives (section 5a). If loading aborts, it fetches the list anew after the next `ready` from `storage` and reads only the files without a result.
- `evt.element.state` `{flowId, elementId, state, countRuns, lastRun}`. `lastRun` is the timestamp of the last start (`yyyy-MM-dd HH:mm:ss`, UTC). `countRuns` is +1 at start and -1 at end (as in v1). `state` is `running` as long as `countRuns > 0`, otherwise `finished`, with result `exception` `exception`. A stop by the engine counts as an end (result `stopped`, state `finished`). For `exception` additionally `message` (message of the exception).
- `evt.instance.ended` `{flowId, instanceId, reason}` with `reason`: `finished` (last thread ended regularly), `exception` (last thread without a matching connection after an exception), `flow.stop`, `toggle`, `policy stop`, `element.stop` (an element stopped its own instance with `ctx.StopInstance`, WI-0052; the reason can be given by the element), `shutdown`, `flow.deleted` (flow deleted or vanished from the table), `trigger removed` (a waiting instance did not find its trigger anymore at start, it ends without `started`). A waiting instance that is stopped also ends without `started`.
- `evt.flow.state` `{flowId, enabled, executing}` after `evt.instance.started` respectively after `evt.instance.ended`. At the end, `evt.flow.state` therefore comes **after** `evt.instance.ended`.
- Boolean values (`enabled`, `executing`, `waiting`) go onto the wire as `true`/`false` (section 2).
- `cmd.flow.start` `{flowId, triggerId?}`: `{instanceId}`, with policy `wait` and a running flow `{instanceId, waiting: true}` (queuing, section `wait` below). Without `triggerId` the first trigger of the flow. A trigger is simulated by the start (`running`, then `finished`, like v1 `newInstance`). Errors: `not_found` (flow not loaded), `bad_payload` (no trigger, no trigger with this ID, invalid policy), `busy` (policy `skip`).
- Policy: `flowSettings.ExecutionPolicy` of the flow, `default` is resolved to `parallel` (a global setting does not exist yet in Phase 2). The decision is made by `ExecutionPolicy.Decide` (WI-0008).
- `cmd.flow.stop` `{flowId}`: `{stopped: n}`, number of stopped instances, waiting ones included (WI-0021). The receipt (`evt.instance.ended`) follows synchronously. Waiting instances are ended first, so that the stop does not let an instance move up.
- **Policy `wait` (WI-0021, E0002, M-0011):** If `cmd.flow.start` starts a flow that is currently running, the engine creates the instance in the state `waiting` and sends `evt.instance.queued`. The response contains `waiting: true`. Order is FIFO per flow, in the order of the starts (not by the order of the instance IDs, unlike v1, which takes the first instance in the order of the instance list). As soon as no started instance of the flow exists anymore, the first waiting one starts (`evt.instance.started`, in the next dispatch pass of the engine, not in the call that ended the previous one). `evt.flow.state` stays `executing: 1` as long as an instance is running, stopping or waiting. The policy is read at start. The trigger and the definition are read from the latest revision when the next instance moves up (E0001). There is no upper limit for the queue (observation point).
- `cmd.flow.toggle` `{flowId}`: `{action: "started"/"stopped", instanceId?}`.
- `cmd.flow.enable` / `cmd.flow.disable` `{flowId}`: `{}`. Only sets the flag and sends `evt.flow.state`. Triggers are not armed for real in Phase 2.
- `cmd.engine.snapshot`: `settings` is `{}` (settings come in Phase 3). `ready` is `true` once the engine has loaded flows and variables and sent `evt.engine.ready`; a client that subscribed after that event reads it here. During loading the answer already lists the flows loaded so far, with `ready: false`.
- `cmd.flow.patch` `{flowId, baseRev, ops}` (WI-0010, only schema and revision): `baseRev` must be an integer, `ops` an array (otherwise `bad_payload`). If `baseRev` differs from the current `rev`, the engine answers with `error.code = "conflict"` and, at payload level, `rev` and `definition` of the current state. All `ops` are checked before any is applied: unknown `op` is `bad_payload` ("unknown patch operation"), known operations (`element.add`, `element.update`, `element.remove`, `connection.add`, `connection.remove`, `flow.settings`) are `bad_payload` ("not applied before phase 3"). An empty `ops` returns `{rev}` without change.

- `cmd.flow.save` `{flowId}` (WI-0039): the engine writes the committed definition with `cmd.storage.flow.write` (path `Flows/<flowId>.json`, `backup` true) and answers when storage has written it: `{savedRev}`, then `evt.flow.saved` `{flowId, savedRev}` on `flow:<id>`. `savedRev` is the revision that was written. Errors: `not_found` (flow not loaded); an error of storage is passed on as it is (`ok: false`, its `error`) and logged. The file carries the root key `formatVersion` (2) and, at every element whose expression texts are still in v1 syntax because its class is unknown, the key `v1Text` (true); see ARCHITECTURE 7. Neither key is in the definition that `cmd.flow.get` returns. The file also carries `flowSettings.strictTypes` (`true`/`false`, the type mode of the flow, E0034, WI-0042, ARCHITECTURE 7); `cmd.flow.get` returns it only when the loaded file had it. Timeout 30 s.
- **Loading converts expression texts (WI-0039):** after parsing, the engine converts the texts of expression parameters from v1 syntax into the new language (doc/EXPRESSION-LANGUAGE.md section 15). `cmd.flow.get` returns the converted texts. Every converted text is logged at level `f2` (flow ID, element, parameter, old and new text); texts that cannot be converted stay and are logged at `f1`.

### 4.4 Engine ↔ trigger host

| Type | From → To | Payload | Response |
|---|---|---|---|
| `cmd.trigger.arm` | engine → triggerhost | `{ triggerKey, flowId, elementId, class, params }` (`params` already evaluated) | `{ ok, message? }` (errors e.g. "hotkey cannot be set") |
| `cmd.trigger.disarm` | engine → triggerhost | `{ triggerKey }` | `{ ok }` |
| `evt.trigger.fired` | triggerhost → engine (`to: "engine"`) | `{ triggerKey, flowId, elementId, data }` | none, the engine decides according to the execution policy |
| `evt.trigger.error` | triggerhost → engine | `{ triggerKey, message }` | – |

`triggerKey` = `<flowId>/<elementId>`. `class` is the qualified ID of the element class, `<package>.<class>` (E0045, WI-0047), for example `Default.Trigger_Hotkey`: the package of the flow element (a missing one is `Default`) and its class, in the spelling of the registered class. On `evt.engine.restarted` the engine re-arms all triggers; the trigger host discards all known ones beforehand.

### 4.5 Engine ↔ worker

| Type | From → To | Payload | Response / event |
|---|---|---|---|
| `cmd.worker.run` | engine → worker | `{ execId, class, params, imports: { name: value }, env: { flowId, elementId, instanceId, threadId }, evaluated: [ { id, value } \| { id, error } ], timeoutMs? }` | `res: { ok }` (accepted) |
| `evt.worker.done` | worker → engine | `{ execId, result, message, exports: { name: value } }` | – |
| `cmd.worker.cancel` | engine → worker | `{ execId }` | `res: { ok }`, then `evt.worker.done` with `result: "stopped"` |
| `cmd.engine.var.*` | worker or client → engine | see "Variable requests" below (WI-0050) | answered at once |

`class` is the qualified ID of the element class, `<package>.<class>` (E0045, WI-0047), for example `Test.Action_TestEchoWorker`: two packages may have a class of the same name, so the class name alone does not name the element. The engine sends the spelling of the registered class. The worker looks it up without regard to case; a class name without a package is an unknown class.

**Implementation in WI-0011 (`src/worker/`):**

- `cmd.worker.run` `{execId, class, params, imports, env, timeoutMs?}`: `env` carries `flowId`, `elementId`, `instanceId`, `threadId`. Response `{ok}` immediately, then the element runs. A second run during execution: `busy`. A class that does not have `Mode := "worker"` ends as `evt.worker.done` with `exception` ("is not a worker element"). A class that the worker does not have ends with `exception` "unknown element class '<class>'", or "element class '<class>' is not available: package '<package>' is not installed" when the worker does not know the package at all (WI-0047). The worker does not use `timeoutMs`: the deadline for acceptance is set by the sender, the runtime of the element is not limited.
- `evt.worker.done` `{execId, result, message, exports}`: `result` is `normal`, `yes`, `no`, `head`, `tail`, `exception` or `stopped`. `exports` is the map from `ctx.Export(name, value)` (only text and numbers). The worker sends it exactly once per run.
- `cmd.worker.cancel` `{execId}`: response `{ok}` (otherwise `not_found`), then `evt.worker.done` with `stopped`. A later `Finish` of the element is discarded. A single long blocking call inside the element cannot receive the cancellation, because AHK only checks messages between command lines (loops in slices are uncritical, see `doc/HOW-TO.md`).
- `sys.shutdown` during a run: `evt.worker.done` with `stopped` before `sys.bye`.

**Implementation in WI-0011 on the engine side (`src/engine/WorkerBridge.ahk`).** The state of WI-0011 (fixed slots `worker:1..n`, workers started from outside) is replaced by WI-0027, see the following section; the points below apply only where the WI-0027 section says nothing different:

- Engine option `--workers=<n>` (0 to 8, default 0 = no pool). Slots are called `worker:1` to `worker:n`. With 0 every worker element ends immediately with `exception` "worker not available".
- A worker element remains `running` until `evt.worker.done` arrives. If all pool slots are occupied, the thread waits (state `ready`) until one is free. If no slot is usable anymore (all `down`), it ends with `exception` "worker not available".
- Response to `cmd.worker.run` with error `not_found`, `timeout` or `internal`: slot becomes `down`, element ends with `exception` "worker not available: worker:n (<code>)". With `peer_gone` (connection of the worker ended, the hub answers immediately): slot is removed, element ends with `exception` "worker crashed (worker:n)", as with `evt.process.crashed` (F-0042, WI-0035).
- Crash or end of a worker: the engine subscribes to the topic `process` at the supervisor (`cmd.topic.subscribe`, only with `--workers` > 0) and evaluates `evt.process.crashed` and `evt.process.exited` for `worker:n`. The running element ends with `exception` "worker crashed (worker:n)". `evt.process.ready` turns a `down` slot back to `idle`.
- `cmd.worker.cancel` when the instance is stopped: the thread ends immediately (as inline, receipt not awaited). The slot remains `busy` until the worker sends `evt.worker.done`, at the latest after 2 s (then `down`, entry in the log `a0`).
- Results from `evt.worker.done`: exports are set as thread variables. An unknown result becomes `exception`.
- `cmd.worker.run` passes `imports` (since WI-0050 empty, see "Imports" below) and `env` with `flowId`, `elementId`, `instanceId`, `threadId`. The acceptance deadline (`timeoutMs`) is 5000 ms.

**Implementation in WI-0027 (elastic pool, ARCHITECTURE 6.4):**

- **Engine options:** `--workers=<n>` (upper limit N, 0 to 8, default 4; 0 = no pool, every worker element ends with `exception` "worker not available"), `--warm-workers=<w>` (default 1, at most N), `--worker-idle-ms=<ms>` (default 60000, 100 to 3600000). The supervisor passes these three options on to all roles if it receives them. Invalid values: engine exit 2.
- **Slots:** `starting` → (`evt.process.ready`) → `idle` ⇄ `busy`. Workers are created only by `cmd.process.spawn` at the supervisor (4.1). There are no slots for workers that the engine did not request itself. Slots and open start requests together are at most N.
- **Demand and warm start:** Waiting worker elements trigger start requests (ARCHITECTURE 6.4). After `OnReady` the engine queries `cmd.process.list` (deadline 5 s), terminates all `worker:*` with `cmd.process.kill` (reason `orphan of a previous engine`) and then requests W workers.
- **Busy:** `sys.busy` (4.1) is sent by the worker, not by the engine.
- **`cmd.worker.run`:** `timeoutMs` is still the acceptance deadline (5000). New and internal to the engine only: a job deadline (`JobTimeoutMs` of the element class), it is not in the message.
- **Response to `cmd.worker.run` with error** (`not_found`, `peer_gone`, `timeout`, `busy`, `internal`): the slot is removed, the worker is terminated with `cmd.process.kill` (reason `run not accepted: <code>`), the element ends with `exception` "worker not available: worker:n (<code>)". Exception `peer_gone`: this is the loss of the worker, not its rejection; the element ends with `exception` "worker crashed (worker:n)" (F-0042, WI-0035).
- **Cancellation:** `cmd.worker.cancel` as before. If no `evt.worker.done` arrives within 2 s, the engine removes the slot and requests `cmd.process.kill` (reason `cancel not confirmed`).
- **Job deadline:** expiry ends the thread with `exception` "worker timeout" and treats the job like a cancellation.
- **Crash/end** (`evt.process.crashed`/`exited` for a slot): slot is dropped, a running job ends with `exception` "worker crashed (worker:n)". This event and `peer_gone` on `cmd.worker.run` report the same death via two paths without a fixed order (the hub answers up to one tick before the supervisor's event); the engine evaluates both the same way, the job ends once, the error is counted once.

**Evaluated parameters (WI-0042, E0026, ELEMENT-API-V2 section 3.1):**

- Before it sends `cmd.worker.run`, the engine evaluates every parameter of the element class (`Parameters()`, labels and buttons left out) with its variables and the type mode of the flow (`strictTypes`), and sends them as `evaluated`: an array in the order of `Parameters()`, one object per parameter, `{ id, value }` or `{ id, error }`. `value` is a text, a number or an object (a variable object; JSON has no integer keys, the worker turns a key of decimal digits back into an Integer as the engine stores it; a float that is not finite is sent as its text). `error` is the text of v1 (`Lang`) that `ctx.EvalParams` throws. `params` stays the raw parameters of the flow. An assignment in a parameter has run before the job is sent, so the element sees its result through the variable requests.
- The worker answers `bad_payload` if `evaluated` is there and is not an array of objects with an `id`. A missing `evaluated` is an empty list (`ctx.EvalParams` then returns no parameters).
- If `Parameters()` of the class throws in the engine, no job is sent: the element ends with `exception` ("parameters of <class> could not be evaluated: <message>").

**Imports (WI-0050, MIGRATION M-0045):** the engine sends `imports` as an empty object. A worker element reaches the variables through the variable requests below, like an inline element; the job carries no copies of them. The field stays for an explicit import list (`ctx.RunScript`, S0008). Exports (`ctx.Export`) are still applied when the job ends.

**Variable requests (WI-0050, ARCHITECTURE R0004).** A worker element reads and changes the variables of the engine with these requests; a client (the flow runner of the tests, later the debugger, ARCHITECTURE 4.3) uses the same ones for a running instance. The engine answers every one of them at once from its variable model: no waiting, no file I/O; a change of a `global` or `static` variable is written later by the write-behind (4.6, WI-0041).

| Type | Payload (besides the address) | Response |
|---|---|---|
| `cmd.engine.var.get` | `{ name, hidden? }` | `{ ok, exists, value, type, location }`: `value` is the value (a copy; `""` if it does not exist), `type` `"object"`, `"normal"` or `""`, `location` `"loop"`, `"thread"`, `"builtin"`, `"instance"`, `"static"`, `"global"` or `""` (one request serves `GetVar`, `GetVarType` and `GetVarLocation`) |
| `cmd.engine.var.set` | `{ name, value, scope?, hidden? }` (`scope` `"thread"` or `"loop"` for an `A_` name) | `{ ok, accepted }`: `accepted` is false when the variable model refused the name or the scope (logged `f0`, as `ctx.SetVar` returns 0) |
| `cmd.engine.var.delete` | `{ name, hidden? }` | `{ ok, existed }` |
| `cmd.engine.var.list` | `{ scope?, withValues? }` (`scope` as `ctx.ListVars`, `""` for all) | `{ ok, names, values? }`: `names` in the order of `ctx.ListVars`; with `withValues` true also `values`, an object name → value of the listed names |
| `cmd.engine.var.import` | `{ vars }` (an object name → value) | `{ ok }`: every entry is set as an instance variable (`ctx.ImportInstanceVars`) |
| `cmd.engine.var.replace` | `{ text, convertObjects? }` | `{ ok, text }`: the `%name%` substitution (`ctx.ReplaceVariables`) |
| `cmd.engine.var.eval` | `{ text, kind? }` (`kind` `"expression"`, the default, or `"script"`) | `{ ok, value }` (`ctx.EvaluateExpression`, `ctx.EvaluateScript`, with the type mode of the flow, E0034) |

- **Address:** exactly one of `execId` (a worker element: the job of `cmd.worker.run`) or `instanceId` (a client), else `bad_payload`. With `execId` the view is that of the running element: its loop, thread and instance variables, the static variables of its flow, the global and the built-in variables, the same `VarAccess` as the element would have inline. The request must come from the worker that runs the job (`from` is the slot of the job), else `denied`. With `instanceId` and optional `threadId` the view is that of the instance (and that thread): without `threadId` there are no loop and thread variables, and setting an `A_` variable is `bad_payload`.
- **`gone`:** the job is not running any more (finished, cancelled by a stop of the instance, ended by its deadline or by the loss of its worker), or the instance or thread does not exist (ended, never started). The engine forgets a job when the instance stops it, before it sends `cmd.worker.cancel`, so a worker element that asks after its stop always gets `gone`; the worker then ends the element (WI-0050). A new engine (restart) does not know any `execId` of the old one: `gone` as well.
- **Errors of the operation:** when the operation fails the way it fails inline (an expression or script with an error, an evaluator warning in strict mode, a hidden `global` or `static` variable, an unknown scope of `list`), the answer is `{ ok: true, elementError: "<text>" }` with the text that the inline function throws. The worker throws `ElementError` with this text. `ok: false` is reserved for errors of the request (`bad_payload`, `gone`, `denied`, `timeout`, `peer_gone`).
- **Values on the wire:** as in `evaluated`: texts, numbers and objects (a variable object; JSON has no Integer keys, the receiver turns a key of decimal digits back into an Integer; a float that is not finite is sent as its text). `true`, `false` and `null` from a client become `1`, `0` and `""`.
- **Timeout:** the worker waits for the answer at most 5000 ms (`WorkerContext.REQUEST_TIMEOUT_MS`); without an answer the variable function throws `ElementError` ("engine did not answer ..."), so does `peer_gone` (the engine went away). A worker may wait blocking (it is its own process); the engine never waits for a worker.
- **Other requests of an element:** `ctx.Request(type, payload, callback, timeoutMs)` (ELEMENT-API-V2 3) sends any `cmd.*` to the engine with `execId` added to the payload and calls `callback(answerPayload)` later, on its own thread, unless the element has ended.

### 4.6 Engine ↔ storage and log

| Type | Payload | Response |
|---|---|---|
| `cmd.storage.flows.list` | `{}` | `{ ok, files: [ {path, name, mtime} ] }` |
| `cmd.storage.flow.read` | `{ path }` | `{ ok, text }` (raw JSON, engine parses) |
| `cmd.storage.flow.write` | `{ path, text, backup: true }` | `{ ok }` (atomic, backups as in v1) |
| `cmd.storage.var.get` | `{ scope: "global"/"static", flowId?, name }` | `{ ok, exists, type, content }` |
| `cmd.storage.var.set` | `{ scope, flowId?, name, type, content }` | `{ ok }` (write-behind, the engine does not wait for it) |
| `cmd.storage.var.delete` | `{ scope, flowId?, name }` | `{ ok, existed }` (deleting twice is no error, `existed` is then false) |
| `cmd.storage.var.list` | `{ scope, flowId? }` | `{ ok, names }` (sorted) |
| `cmd.storage.settings.get/set` | `{ settings? }` | `{ ok, settings }` (Phase 3, not yet implemented) |
| `evt.log.append` (`noReply`) | `{ ts, level, source, flowId?, text }` | none. Storage writes `Log.txt`, `Log_<source>.txt` and forwards to topic `log`. |

`evt.log.append` is droppable (F-0016, F-0066): a sender (`Role`) drops it above 500 frames in its send queue, and the hub drops it above 800 frames in the queue to the target, so a log burst never overflows a queue (which would close the connection). Drops are counted and announced by one line "n log lines dropped" when there is room again. No other message type is dropped this way.

**Implementation in WI-0012 (`src/storage/`):**

- All responses go through the queue (`WriteQueue`, two queues, time budget per timer run, see WI-0025 below). The response is `Deferred` (section 2). Every request is answered exactly once, also on deadline, error or shutdown (`shutting_down`).
- Deadline: `timeoutMs` of the request (default 30000). An operation that waited longer than the deadline is not executed and is answered with `timeout`.
- `cmd.storage.flows.list`: `path` is `Flows/<name>.json` relative to the data directory, `name` the file name without `.json` (this is the `flowId` of the engine). `mtime` as an integer (seconds since 1970).
- `cmd.storage.flow.read`: `not_found` if the file is missing.
- `cmd.storage.flow.write`: `text` must be a JSON object (otherwise `bad_payload`). Writing is atomic (temp file + `MoveFileEx`), with CRLF as in v1. `backup` (default true): before replacing, the old file is copied to `Flows/backup/<name>_backup_<yyyyMMddHHmmss><ms>.json`, at most 10 are kept. If the backup fails, nothing is written (`internal`).
- Paths are checked before every file access (`bad_payload` for `..`, backslash, subfolder, wrong extension). Names of variables and flow IDs must not contain path characters.
- `cmd.storage.var.*`: `scope` `global` (files in `Variables/`) or `static` (in `Variables/<flowId>/`). `type` is `normal` (content is the value as text) or `object` (content is JSON text, storage checks it). `var.get` returns `exists: false` if the metadata file is missing. Content is returned unchanged.
- Errors: `ok:false` with `error.code` to the sender, additionally `evt.storage.error` to topic `engine` (`op` = name without `cmd.storage.`, e.g. `flow.read`, `flow.write`, `var.set`).
- `evt.log.append`: An entry is appended as a line `CRLF, "--- yyyy MM dd HH:mm:ss ~<sender>~<source>~ <text>"` to `Log/Log.txt` and `Log/Log_<source>.txt` (timestamp local as in v1, `ts` comes in UTC). A file larger than 100 KB is first renamed to `<name>_old.txt`. The entry is forwarded as `evt.log.entry` `{ts, level, source, flowId?, text}` to topic `log` (`ts` unchanged, UTC). Storage itself writes its entries directly into the queue, not to itself.

- **Use by the engine (WI-0041, M-0006):** The engine does not read variable files itself. The messages keep the names `cmd.storage.var.get`, `.set`, `.delete`, `.list` (no new message type).
  - *Loading:* after the flow files and before `evt.engine.ready` the engine sends `cmd.storage.var.list` for `global` and for `static` of each loaded flow, then `cmd.storage.var.get` for every name. At most 2 requests are on their way (`VarLoader.PARALLEL`); the next leaves when an answer has been handled. Timeout 30 s per request. If `storage` is gone or silent, nothing more is sent, no error is reported, and the engine waits for `storage` as for the flows (ARCHITECTURE 6.1); afterwards only the variables without a result are asked for. A variable that cannot be read (`internal`, content not JSON) is reported as `evt.storage.error` (`op` `var.get`, `path` `<scope>[/<flowId>]/<name>`) and skipped. Content of type `normal` stays a text in memory (M-0039); `object` is parsed.
  - *Writing:* `cmd.storage.var.set` (type `normal` with the text form, or `object` with the JSON text, indented by 2) or `cmd.storage.var.delete`, one request per changed variable, sent `--var-write-delay-ms` (default 200) after the first change since the last write; later changes inside the delay are part of the same write (the state at the moment of sending counts). The request limit is `--var-write-timeout-ms` (default 10000). On a timeout, `peer_gone`, `shutting_down`, `busy` or `internal`, the variable is marked again and retried after 1 s, without limit; the working copy stays. The first failure of a variable is reported (`evt.storage.error` with `op` `var.set` or `var.delete`, log `a0`), further ones are not until a write succeeds. `bad_payload` (a name or content that storage refuses) is reported and not retried. At most 50 requests leave per timer run and at most 200 are unanswered at the same time.
  - *Shutdown:* `Engine.OnShutdown` stops the instances and then sends every variable that is still marked, with the rest of `deadlineMs` (at least 500 ms) as the request limit, before `sys.bye`. It does not wait for the answers: the frames precede `sys.bye` in the send queue, and `storage` is the last process to end and empties its queue (ARCHITECTURE 6.3).
  - *Engine options* `--var-write-delay-ms=<0..60000>` and `--var-write-timeout-ms=<100..120000>`: the supervisor passes both on to the engine (exit 2 for an invalid value). Meant for tests.
  - *File format written by v2:* `.ahfvar` and `.ahfvd` as in v1 (pair, `.ahfvd` JSON `{name, type}`), without BOM, CRLF in JSON (`VarFiles.Set`). Reading accepts files with and without BOM. A number is written as its text and comes back as a text (M-0039); in an object it stays a JSON number.
- **Queues, throughput and log limit (WI-0025, F-0007):** `WriteQueue` has two queues: requests (`cmd.storage.*`) and log operations. A waiting request always runs before the next log operation; the order within each queue remains. A timer run processes operations until the time budget (`WriteQueue.BUDGET_MS` = 10 ms, checked between two operations) is used up or nothing is left to run; a single large operation (5 MB write) is never split. Afterwards the run releases the message loop (`sys.ping`, new requests). Log lines are bundled per file: at most 500 lines or 64 K characters per operation, the file is opened once (rotation beforehand, as before), all lines are written in one go. If the file is held by another process (F-0003), the bundle including new lines stays at the front of the log queue and is retried every 20 ms for up to 3 s; requests continue meanwhile. After that the lines count as lost (counted, `log line lost`, at most 5 lines per bundle listed individually). `evt.log.entry` is sent to topic `log` as before, after writing the last file (`Log_<source>.txt`) of the entry. **Limit:** at most 20000 entries or 8 MiB (characters) wait at the same time. Above that, new entries are discarded and counted (never block, no error to the sender); as soon as at most half is occupied (or at the next accepted entry), storage writes an entry of source `storage`, level `a0`: `<n> log lines dropped (log queue was full, <total> in total)`. The limits can be lowered for tests with `--log-queue-max-lines=<n>` and `--log-queue-max-chars=<n>`. **Cleanup at start:** as the first log operation, storage deletes `*.ahf-<pid>.tmp` in `Flows/` and `Variables/` (recursively) whose process is no longer running (a process that cannot be opened counts as running). Atomic writing calls `FlushFileBuffers` on the temp file before the rename.
- **Log threshold and ring buffer (WI-0023):** The option `--log-level=<0..3>` (default 2) applies to the supervisor and is passed by it to every role. An entry with a digit above the threshold (`a3`, `f3`, `t3` at default) is **not** forwarded to the sink (`storage`). Every process keeps the last 500 entries of all levels in memory independently of the sink (`Log.Recent()`, basis of the crash report, WI-0028). Invalid value: role exit 2, supervisor exit 1 (message on stderr). A setting for this later (Phase 3).
- **Log of the supervisor (WI-0023):** The supervisor is not a `Role` and has no peer, but it sends its entries like every role as `evt.log.append` (sender `supervisor`) via the hub to `storage`, as long as `storage` is connected (`DiagLog`, `src/supervisor/DiagLog.ahk`). Before that and between two `storage` runs (restart) they wait in a queue (at most `Role.LOG_QUEUE_MAX` = 500, the oldest fall out and are counted), which is emptied in order when `storage` sends `sys.hello`. In addition, the supervisor continues to write to stderr. An error while sending does not log again (flag against recursion). Sources of the supervisor: `supervisor`, `hub`, `children`, `shutdown`.

### 4.7 Dialogs

The engine never shows dialogs. If the user must react, the engine uses a worker (dialog element, mode `worker`) or sends to the UI role:

| Type | From → To | Payload | Response |
|---|---|---|---|
| `evt.ui.notice` | engine/storage → `manager` | `{ level, text, flowId? }` | – (tray notice instead of MsgBox) |
| `cmd.ui.confirmDeleteFlowFile` | engine → `manager` | `{ path, reason: "missing_packages", packages }` | `res: { ok, delete: bool }` (v1: MsgBox in `LoadFlow`) |

### 4.8 Manager stub (WI-0013, `src/manager/`, only `--ui=stub`)

The stub is a minimal replacement for `manager` (ARCHITECTURE 3). It shows what the engine reports. It holds only UI state and no truth about the execution.

- **Subscriptions:** `engine`, `process`, `log`, after the snapshot additionally `flow:<flowId>` for each flow.
- **Resync:** `cmd.engine.snapshot` after `evt.engine.ready`, after `evt.flow.list.changed`, after `evt.process.restarted` (name `engine`), on a new `epoch`, on a gap in `seq` and on an outdated response (a response with a smaller `seq` than already seen is repeated). Duplicate events (`seq` already seen) are discarded.
- **Response to `cmd.app.prepareExit`:** `{ ok: true, cancel: false }`, with option `--stub-cancel-exit` `cancel: true` (section 2).
- **Events as log lines:** every received `evt.*` (except topic `log`) is sent as `evt.log.append` to `storage`, source `manager`, text `ui-event {json}`. Storage writes `Log/Log_manager.txt`. The field `recvMs` is the wall-clock time (ms, UTC) on arrival. The lines `stub.*` are the stub's own entries (`stub.ready`, `stub.snapshot` with `reason`, `stub.command`, `stub.commandAnswer`, `stub.prepareExit`, `stub.show`, `stub.shutdown`).
- **Test command `cmd.test.command` (only with `--headless`):** payload `{ type, payload }`, `type` from `cmd.flow.start`, `cmd.flow.stop`, `cmd.flow.toggle`, `cmd.engine.snapshot`. The stub forwards the request to `engine` and answers with `{ ok: true, answer: <answer of the engine> }`. Other types: `bad_payload`. The answer comes delayed (`Deferred`).
- **`cmd.manager.show` (F-0074):** supervisor → `manager`, payload `{}`, response `{ ok: true }`. The manager makes its window visible and brings it to the front (restores it if minimized). The supervisor sends it when a second start without `--command` arrives (`cmd.app.command` with empty `argv`, 4.1), as v1 did. A manager without a window (`--headless`) only records the request and answers `ok`. If no `manager` is connected, the request is not sent: that outcome is called `not_running` (the supervisor's own result, logged; it is never put on the wire). The supervisor then starts the manager if a start is allowed, and the new manager shows its window on its own start.
  Example: `{"to":"manager","from":"supervisor","id":"s-41","type":"cmd.manager.show","timeoutMs":3000,"payload":{}}` answered by `{"to":"supervisor","from":"manager","corr":"s-41","type":"res.manager.show","payload":{"ok":true}}`.
- **Options that the supervisor passes to all roles:** `--ui=<word>`, `--headless`, `--stub-cancel-exit`, `--log-level=<0..3>` (WI-0023), `--workers=<n>`, `--warm-workers=<n>`, `--worker-idle-ms=<ms>` (WI-0027, pool of the engine, 4.5), `--var-write-delay-ms=<ms>`, `--var-write-timeout-ms=<ms>` (WI-0041, variable files of the engine, 4.6).
- **`evt.engine.restarted`:** The engine sends it itself (it owns the `epoch`), as soon as it has loaded the flows after a restart, directly before `evt.flow.list.changed` and `evt.engine.ready`. It recognizes the restart by the option `--restarted=<n>`, which the supervisor appends only on an automatic restart (`n` = number of restarts in the window). At the first start the option is missing, then no `evt.engine.restarted` comes. The stub additionally triggers the resync via `evt.process.restarted` and a new `epoch`.

### 4.9 Diagnostics II: snapshot, crash report, debug window (WI-0028)

Not a flow debugger (E0001), but diagnostics of the system. Everything here is read-only, except for the writing of the reports by `storage`.

**`cmd.diag.snapshot`** (any role → every role, also `supervisor`; deadline of the caller, default 2 s)

| Request | Response |
|---|---|
| `{}` (The field `content` is reserved for the future flow debugger and is ignored: a snapshot **never** contains contents of variables or flows, only names, IDs, counters and states.) | `{ ok, snapshot }` |

`snapshot` is an object with `schema: 1` and these fields. The general part comes from the base class `Role` (`Role.Snapshot`), the role part `info` from the hook `Role.DiagInfo()` (default: empty object). An error in the hook yields `info: { error: "<text>" }`, never an error of the response.

| Field | Content |
|---|---|
| `name`, `role`, `pid` | role name (`editor:Flow 1`), role (`editor`), process ID |
| `startedAt`, `uptimeMs` | process start (UTC, `yyyy-MM-dd HH:mm:ss`, from `GetProcessTimes`) and runtime |
| `version`, `ahkVersion`, `bits` | `AhfVersion.Current` (`src/core/AhfVersion.ahk`), `A_AhkVersion`, 64 |
| `rssBytes`, `handles` | memory (`GetProcessMemoryInfo`) and handle count (`GetProcessHandleCount`) of the own process |
| `peer` | `{ status, pending, lateReplies, badFrames, droppedSends, queuedFrames, queuedBytes, handlerErrors }` (counters of `Peer` and its connection, `Peer.Stats()`) |
| `log` | `{ queued, dropped, sinkErrors, lastSinkError, level, recent: [ {ts, level, source, text} ] }`: `Role.LogStats()`, `Log.sinkErrors`, the last 100 entries of the ring buffer of `Log` (WI-0023, texts truncated to 500 characters) |
| `errors` | `{ count, recent: [ {ts, errorType, message, file, line, stack, mode} ] }`: the last 20 unhandled errors of the role (WI-0023) with stack |
| `info` | role part, see below |

Role parts (`info`):

| Role | Fields |
|---|---|
| `engine` | `epoch`, `seq`, `flows: [ {flowId, name, rev, enabled, executing} ]`, `instances: [ {instanceId, flowId, state, threads: [ {threadId, elementId, state, result} ]} ]`, `workers: { size, warm, slots: [ {name, state, execId} ], spawning, failures }` |
| `storage` | `queue: { requests, log }` (length of the two queues), `logQueuedEntries`, `logQueuedChars`, `logLinesLost`, `logLinesDropped` |
| `worker` | `job`: empty if no job is running, otherwise `{ execId, class, sinceMs }` |
| `manager` (stub) | `topics`, `epoch`, `lastSeq`, `flows` (count), `events`, `resyncs` |
| `debug` | `topics`, `processes` (names), `snapshots` (roles with snapshot), `logEntries`, `engineEvents`, `dumps`, `paused` |

The supervisor answers the request itself (it is not a `Role` and has no peer). Instead of `peer` and `info`, its snapshot has: `hub` (`{ links: [ {name, pid, queuedFrames, queuedBytes, topics} ], droppedAnswers, pending, routedOpen, goneAnswers }`; `routedOpen` = forwarded requests between clients without response, `goneAnswers` = of these, those answered with `peer_gone` because the target was lost, section 2, WI-0034), `children` (per child `{ name, role, state, pid, exitCode, restarts, startedAt, busy, killReason, output: [last 100 lines stdout/stderr] }`, also for ended children), `diagErrors` (ring of `evt.diag.error`, up to 50, complete with stack), `diagLog` (`{ queued, dropped }`), `processEvents` (the last 50 events of the topic `process`: `{ts, type, payload}`), `reports` (`{ written, unwritten, autoSuppressed }`). `log` and `errors` are also available there.

**`cmd.diag.report`** (any role → `supervisor`)

| Request | Response |
|---|---|
| `{ reason }` (text, 1 to 60 characters; characters other than letters, digits, `.`, `_`, `-` become `-` in the directory name) | `{ ok, path, dir, roles, missing: [ {name, why} ] }` (response delayed, `Deferred`) |

Procedure in the supervisor (`DiagReport`, `src/supervisor/DiagReport.ahk`): It queries **every connected role** simultaneously with `cmd.diag.snapshot` (deadline per role `DiagReport.SNAPSHOT_MS` = 2000 ms; there is no waiting without a deadline). Roles that are not connected (started, crashed, ended) and roles that do not answer are listed in `missing` with the reason (`not connected (<state>)`, `no answer within 2000 ms`, `error: <code>`). When all responses or deadlines are in, the supervisor adds its own snapshot (with the output buffers of children that have already died) and builds two files: `report.json` (all snapshots, `meta`: reason, time, automatic yes/no, version, session) and `summary.txt` (readable summary: process table, per role the most important figures, missing roles, last errors). Both go to `storage` (`cmd.storage.report.write`). The supervisor never writes files itself.

*Automatic reports.* The supervisor triggers `reason = "<trigger>-<name>"` itself on: unexpected end of a child (`crashed-<name>`), reached restart limit (`restart-limit-<name>`), `hung-<name>`, and when a role reports `DiagReport.ERROR_BURST` (10) unhandled errors within 60 s (`errors-<name>`). **Rate limit:** at most one automatic report every 60 s (`DiagReport.AUTO_MIN_INTERVAL_MS`); further triggers in this time are discarded, counted (`reports.autoSuppressed`) and logged with `a1`. During the exit (`Children.shuttingDown`) there is no automatic report. Manual reports (`cmd.diag.report`) are not limited.

*Storage not reachable.* If `storage` is not connected (crashed, in restart), the finished report waits in the memory of the supervisor for the newly started storage, at most `DiagReport.STORAGE_WAIT_MS` (10 s). If `storage` comes in time (`sys.hello`), it is written and the caller is answered. Otherwise the supervisor answers the caller with `error.code = "peer_gone"` ("storage not available, the report is kept and written when storage is back"). The report then stays in memory (at most `DiagReport.KEEP_UNWRITTEN` = 5, the oldest falls out) and is written on the next connection of `storage`, under the original timestamp.

**`cmd.storage.report.write`** (`supervisor` → `storage`; other senders: `denied`)

| Request | Response |
|---|---|
| `{ stamp, reason, files: { "<file>": "<text>" } }`. `stamp` = `yyyyMMdd-HHmmss` (local time of the supervisor), `reason` as above, file names only `[A-Za-z0-9._-]`, no paths | `{ ok, path, dir, removed, logs: [ ... ] }`: `path` = `Reports/<stamp>_<reason>` relative to the data directory, `dir` absolute, `removed` = number of old reports deleted due to retention, `logs` = copied log files |

Storage creates `Reports/<stamp>_<reason>/` (if it exists, `-2`, `-3` ... is appended), writes the files atomically, copies `Log/Log.txt` and `Log/Log_old.txt` into it if present (an unreadable file is skipped and not listed in `logs`), and then keeps at most 20 report folders (the oldest by name fall away). The operation runs in the request queue (deadline of the caller, 30 s default). Errors: `bad_payload` (names), `denied`, `internal`.

**Topic `debug`, `evt.debug.dump`.** `Debug.Dump(value, title := "")` (`src/core/Debug.ahk`) replaces `d()` from v1. It converts `value` into readable JSON (depth at most 8, at most 200 entries per map or array, cycles and foreign objects as `<type>`), truncates at 60000 characters and sends `evt.debug.dump { title, ts, json, truncated }` (`truncated` is a boolean value) to `topic:debug`. `from` is set by the hub. **Never blocks, never throws:** without a running role, without a ready connection, or on an error it does nothing. At most 100 calls per second and process (`Debug.MAX_PER_SECOND`); the rest is discarded and counted (`Debug.dropped`). If nobody has subscribed to the topic, the hub discards the event.

**Role `debug`** (0..1 process, `src/debugview/DebugView.ahk` and `DebugGui.ahk`; option `--headless`). Its own process like the manager stub: never modal, no `MsgBox`, no files. It subscribes to `process`, `log`, `engine`, `debug` and `flow:<id>` (after `cmd.engine.snapshot`, like the stub). It shows: process table (`cmd.process.list` plus events), the snapshot per role (button "Refresh" and checkbox "every 2 s": `cmd.diag.snapshot` to every ready role and to `supervisor`, deadline 3 s), the live log with filter (level and source), the event stream of the engine with pause, the `Debug.Dump` values, and the button "Export report" (`cmd.diag.report {reason: "manual"}`, shows the path). It is started with `--start=debug` or by `--command=debug` to a running instance (`cmd.app.command`). If the user closes the window, only this role ends (`sys.bye {clean: true}`, exit 0); the supervisor treats this as a normal end (`evt.process.exited`, no `crashed`, no automatic report), see 4.1a. It is never restarted automatically and, when exiting, it is terminated first together with the UIs (rank 0, without `cmd.app.prepareExit`).

- **Test command `cmd.test.debug` (only with `--headless`):** `{ action }` with `state` (counters and lists of the model: `processes` names, `states` state per process (name → state according to ARCHITECTURE 5.3), `snapshots` role names, `logEntries`, `engineEvents`, `dumps` titles, `paused`, `lastExport`), `refresh` (fetches the snapshots, response after the last one; `refreshed` counts the responses; a process that is not `ready` is not asked, its entry reads `not ready (state: <state>)`), `export` (triggers `cmd.diag.report`, response with its result), `pause`/`resume`, `filter` (`{level, source}`; response `state`), `snapshot` (`{name}`: the stored snapshot text, `not_found` without), `close` (like closing the window: only this role ends, with `sys.bye {clean: true}`). Others: `bad_payload`.
- **Echo test command `cmd.test.dump { title, value }`** (test role `echo`): calls `Debug.Dump(value, title)`.

## 5. Connection setup, reconnection, resync

1. A role connects, sends `sys.hello` with the `hwnd` of its window (wake-up target, section 1). The hub answers with `sys.welcome`. Until then the role sends nothing except `sys.hello`. The peer (`src/core/ipc/Peer.ahk`) opens the pipe without waiting (one attempt, then retry via timer), wakes the hub with `sys.hello` already when the hub HWND is known (option `hubHwnd`), and reports `ready` only after `sys.welcome`.
2. The role subscribes to topics, calls `cmd.engine.snapshot` (UIs), and begins processing events with `seq`.
3. If the pipe breaks, the role rebuilds the connection (backoff 100 ms, 200, 400, ..., max. 2 s, total 10 s), repeats `hello` with the `epoch` of the owner, subscribes again, and performs a resync. If this fails, the role terminates itself (orphan guard).
4. A gap in `seq` or a new `epoch` triggers a resync.
5. The hub keeps an output queue with an upper limit per client (default 1000 messages or 8 MiB). If it overflows, the client counts as hanging (`peer_gone` for pending requests, implemented since WI-0034, section 2 "Target lost before the response"), and the supervisor is informed.

6. **Loading large amounts of data (WI-0024):** Whoever requests many large responses (the engine at start: one `cmd.storage.flow.read` per flow file) does not send all requests at once, but at most K at a time (engine: K = 2) and the next one after processing a response. This way a `sys.ping` is at most behind K responses in the pipe. The hub forwards large frames via the header fields (section 2); its cost per frame is independent of the size of the payload (measured 1.7 ms for 109,232 characters). The receiver's costs remain: `Message.Parse` of the frame (0.16 s) and `Json.Parse` of the flow text (0.14 s) for the largest v1 file.

### 5a Events before subscription (design question, WI-0007)

Events are only distributed to subscribers who are subscribed at the time of sending. An event that was sent before a role's `cmd.topic.subscribe` is lost for this role. There is no persistence and no repetition (section 1, delivery).

From this follows the rule for late joiners (e.g. a manager that opens after the supervisor has started):
1. Subscribe first (`cmd.topic.subscribe`), then fetch the current state (`cmd.process.list` at the supervisor, `cmd.engine.snapshot` at the engine).
2. Events that arrive between these two steps may occur twice (snapshot and event). The receiver must not count them twice as state changes; the snapshot is authoritative.
3. An event that never arrived is not made up for. The snapshot corrects it.

The supervisor keeps no history for `process`. `cmd.process.list` is the only source for the state before subscription. `tests/integration/test_supervisor.py` uses the snapshot (`process_list`) to wait for readiness and for the state check after a crash. A targeted test in which a late joiner misses events is missing (not checked).

## 6. Versioning and extension

- `sys.hello.protocol` is the integer version. Differences in the major version lead to `error.code = "denied"` in `sys.welcome` and termination of the role.
- Unknown fields in payloads are ignored, unknown `type` values are answered with `unknown_type` (requests) or logged and discarded (events).
- New commands are added to this catalog together with a test in `tests/integration/test_protocol_*.py`.
