# Architecture AutoHotFlow v2

Status: Draft, approved as the basis for Phase 2 (walking skeleton), extended in Phase 2b (WI-0020, decisions E0001 to E0008 in `doc/DECISIONS.md`). As of 2026-10-11.
Target platform: AutoHotkey v2, **64-bit only** (E0004, 2026-10-11). 32-bit is not supported and is rejected at startup (implementation in WI-0022). Reason: structures and DllCalls are only tested for 64-bit. Stock interpreter, no AHK_H extensions.
Related documents: [REQUIREMENTS.md](REQUIREMENTS.md) (what AutoHotFlow must do), [PROTOCOL.md](PROTOCOL.md), [ELEMENT-API-V2.md](ELEMENT-API-V2.md), [TEST-STRATEGY.md](TEST-STRATEGY.md), [CONVENTIONS.md](CONVENTIONS.md), [MIGRATION.md](MIGRATION.md).

Labeling: **[M]** = measured or confirmed in a spike, **[V1]** = verified in the v1 code, **[A]** = assumption to be checked in Phase 2.

---

## 1. Goals

1. Deadlocks and race conditions **can no longer arise by construction**: no shared memory, no global lock, every datum has exactly one writing owner.
2. No blocking call in the message path. File I/O and dialogs never run in the engine.
3. A hanging or crashing process does not take any other process with it. The system detects it and reacts in a defined way.
4. Old flows (`.json`) and variables (`.ahfvd`/`.ahfvar`) load as they are (no conversion of the files beforehand). How v2 writes is free (E0021). A loaded v1 flow may need small fixes; every such place is marked with its MIGRATION ID and keeps the v1 original (E0035).
5. The element format of the 114 actions plus conditions, loops and triggers can be ported largely mechanically.

Non-goals of the port: new features beyond the scope of v1, except those decided for the port (`doc/REQUIREMENTS.md`, scope `port`; ideas for after the port have the scope `later` there); a new flow file format; a plugin sandbox against malicious element code (REQ-SEC-030).

---

## 2. Decisions

| # | Decision | Rationale |
|---|---|---|
| D0001 | **Multiple processes, no threads.** | AHK v2 has no threads within the same process. Pseudo-threads are cooperative: one blocking operation stops everything. Real parallelism only exists through processes. |
| D0002 | **One editor process per open flow.** | Several editors are open at the same time, and even unfocused ones must be updated continuously. One process per editor decouples drawing, input and crashes. Cost **[M]**: ~30 ms start, ~14 MB RSS, 0 % CPU when idle, per process. This is negligible. |
| D0003 | **Manager (flow list, settings, import/export) is its own process.** | As with the editor: dialogs and the tree view must never stall the engine. |
| D0004 | **Drawing runs in the editor process, behind a narrow `Renderer` interface.** | See 2.1. This makes it separable into its own process later without reworking the editor. |
| D0005 | **IPC: named pipes (byte mode, overlapped) for data, `PostMessage` only as a wake-up call.** | See 2.2. `WM_COPYDATA` rejected. |
| D0006 | **Star topology: the supervisor is the hub.** All processes connect to it, and it routes. | Keeps connections stable even when the engine restarts; the single place for process monitoring. The supervisor contains no business logic and never blocks. |
| D0007 | **One `storage` process owns all files** (flows, variables, settings, logs). | I/O never in the critical path. One writer per file prevents file conflicts between processes. In v1 this was only solved through the global lock, which had to be held for it. |
| D0008 | **One `triggerhost` process holds OS hooks, hotkeys and trigger timers.** | Low-level hooks must respond quickly, or Windows removes them. This must not depend on engine load. Trigger types can later be distributed across several hosts. |
| D0009 | **Elements run in a hybrid way: `inline` in the engine or `worker` in their own process.** | See 2.3. Blocking, risky or UI-showing elements run in workers. This corresponds to the v1 pattern "own thread for AHK code". |
| D0010 | **The editor holds a draft, the engine owns the committed definition.** Changes are applied as patches with a revision number. | See 4.2. One editor per flow, so there are no multi-writer conflicts. |
| D0011 | **Flow file format stays unchanged** (JSON, `ElementIDCounter` etc.). **Narrowed by E0021:** v2 must read the v1 format; how it writes is free (so far: the v1 format plus `formatVersion`, `v1Text`, `strictTypes`, see 7). | Requirement 4. See 7. |
| D0012 | **One entry script per role (E0041, 2026-10-15; before: one entry point `AutoHotFlow.ahk --role=<name>`).** `src/AutoHotFlow.ahk` is the file the user starts and runs the supervisor. Every other role has its own script `src/entry/<role>.ahk` (`storage`, `engine`, `worker`, `manager`, `debug`, `triggerhost`, `editor`), which includes the shared boot code `src/AhfBoot.ahk`, the code of its own role and its generated block of element classes, registers the role and calls `AhfMain()`. The supervisor starts a child as `AutoHotkey64.exe <entry folder>\<role>.ahk --role=<name> --session=... --hub=... --data=...`; the entry folder is `entry\` next to the script of the supervisor (with `--test-roles` also `entry\test\`). A role name without an entry file is an unknown role (`bad_args` at `Spawn`). `--role` stays on the command line (the role gets its full name, e.g. `worker:3`), but an entry registers only its own role: any other value ends with exit 2, "unknown role". | Each process parses only what it needs (R0003, MS-0032, MS-0033). The entry folder is a convention instead of a table in the supervisor, so a new role needs no change in `src/supervisor/`. |
| D0013 | **Tests with pytest as the e2e driver plus small AHK unit tests.** | See [TEST-STRATEGY.md](TEST-STRATEGY.md). |

### 2.1 Drawing in the editor process (D0004)

Starting point: v1 had a central draw thread that drew all flows and competed for the same lock while doing so. This was one cause of the poor performance.

In v2 each editor process draws only its own flow, with its own process and without shared locks. Several editors therefore draw in parallel on different CPU cores. The remaining disadvantage: a long drawing operation blocks the input of **the same** editor. We mitigate this through:

- Drawing only on change (dirty flag), coalescing several changes into one frame, upper limit of about 30 frames/s.
- The `Renderer` receives an **immutable scene snapshot** (`Scene`: elements, connections, view, states) and a target (HWND or bitmap). It does not read editor state directly.

Separability: if the call `Renderer.Draw(scene, target)` is replaced by a message `cmd.render.draw {scene}` to a `render` process that renders into a shared bitmap (file mapping), only the editor adapter changes. The renderer code stays the same.

Criterion for separation **[A]**: If a frame for a realistic large flow (e.g. 300 elements) averages more than 16 ms, or the input noticeably stutters, the render process is built. The measurement is part of Phase 3 (editor).

### 2.2 IPC (D0005)

Compared: named pipes and `WM_COPYDATA`.

| Criterion | Named pipe | WM_COPYDATA |
|---|---|---|
| Direction / separation | bidirectional, separated per connection | one window handle needed per direction |
| Blocking | writing in overlapped mode with timeout, caller remains able to act | `SendMessage` blocks until the receiver has processed the message. A hanging receiver hangs the sender (exactly the deadlock we want to avoid). `PostMessage` is not possible, because the data pointer must stay valid. |
| Crash detection | peer gone → `ERROR_BROKEN_PIPE` | only via window handle check |
| Size | free (frame with length prefix) | limited by memory, UIPI problems with elevated processes |
| Effort | higher (DllCall, OVERLAPPED) | low |

**Decision:** named pipes. The effort was checked in a spike **[M]**:

- An AHK v2 process runs an overlapped pipe server via `DllCall`. A Python process connects with `open(r"\\.\pipe\name", "r+b", buffering=0)`. This makes pytest-based e2e tests possible without an additional library.
- Pure polling (timer 250 ms) gives round trips of around 250 ms. With `PostMessage` as a wake-up call after writing, the round-trip time drops to **~0.3 ms** (median).
- The spike is in `v2-phase2-final:work_items/spikes/` (`pipe_server.ahk`, `client.py`).

Consequences:

- After each write, the sender sends `PostMessage(peerHwnd, WM_AHF_WAKE)`. On a wake-up call the receiver reads **and** additionally via a fallback timer (250 ms), so that a lost wake-up call blocks nothing.
- The HWNDs are exchanged in the handshake (`sys.hello`/`sys.welcome`).
- Pipes are `PIPE_REJECT_REMOTE_CLIENTS` and have a protected DACL (system and owner only); the name contains a session ID.

### 2.3 Element execution: inline or worker (D0009)

AHK v2 has no `await`. An element that uses `RunWait`, `WinWait`, a download or a dialog would stall the engine.

| Mode | Runs in | For | Rule |
|---|---|---|---|
| `inline` | engine | fast, non-blocking elements (variables, strings, numbers, lists, timers via `SetTimer`) | must **never** block. Anything long runs via `ctx.After(ms, fn)` or is split into parts. |
| `worker` | own process from a pool | blocking, risky or UI-showing elements: dialogs (`MsgBox`, `InputBox`, `FileSelect`), `RunWait`, network, COM, DllCall, AHK script | receives **evaluated parameters**; reads and changes variables with requests to the engine (R0004, WI-0050, waiting blocking for the answer), returns result plus export variables |
| `trigger` | triggerhost | all triggers | see [ELEMENT-API-V2.md](ELEMENT-API-V2.md) |

This fulfills the requirement "no UI dialogs from the engine": dialog elements run in the worker. The engine "asks the UI by message". The worker is the UI process for this.

An incorrectly classified inline action does not fail silently: the engine watchdog (6.2) reports when an element call runs longer than 250 ms in the engine process, with class and flow.

**Decision E0003 (2026-10-11):** The supervisor starts and stops worker processes on request of the engine (elastic pool). A worker that is processing a job is exempt from the ping check. Deadlines for jobs are held by the engine. The rules are in section 6.4 (WI-0027).

---

## 3. Processes

| Role (`--role`) | Count | Task | Owns | Never does |
|---|---:|---|---|---|
| `supervisor` | 1 | start, monitoring, restart, shutdown, hub/router, tray icon (hidden by `#NoTrayIcon`, E0046; the icon is the manager's) | process list, session ID | business logic, file I/O, dialogs |
| `storage` | 1 | file access, log sink, settings file | all files under the data directory | business decisions, dialogs |
| `engine` | 1 | flow definitions (committed), instances, threads, variables, execution of inline elements, trigger target state | runtime state | block, touch files, show dialogs |
| `triggerhost` | 1 (later n) | arm triggers, report events | OS handles of the triggers (hotkeys, hooks, timers) | execute flows |
| `manager` | 0..1 | flow list, categories, settings, import/export, log display | window state | execute flows |
| `editor:<flowId>` | 0..n | edit and display a flow, drawing | draft of the flow, undo/redo, view (zoom/offset), selection | change runtime state |
| `worker:<n>` | 0..N (elastic pool, section 6.4) | execute blocking/UI elements | only a short-lived copy of the task | hold state |
| `debug` | 0..1 | debug window: process table, snapshot per role, live log, event stream, `Debug.Dump` values, export report (WI-0028, PROTOCOL 4.9) | window state, view filter | change state of other roles, touch files |

The supervisor is the smallest and simplest process. It is a hub, because a restart of the engine then does not destroy the clients' connections. If the supervisor itself fails, all children terminate after a short deadline (orphan guard, see 6.3).

---

## 4. Data ownership

**One owner per datum.** All others receive copies or events, never references.

| Datum | Owner (sole writer) | Copies / consumers |
|---|---|---|
| Flow definition (committed, with `rev`) | engine | editor (draft), manager (metadata for the list) |
| Flow draft, undo/redo, selection, zoom, offset | `editor:<flowId>` | – |
| Instances, threads, element execution status | engine | UI via event (`evt.element.state`) |
| Variables `instance`/`thread`/`loop` (each with a hidden table) | engine: `Instance.Vars`, `ThreadState.Vars`, `ThreadState.Loops` (WI-0040, doc/EXPRESSION-LANGUAGE.md section 18) | – (a worker element reads and changes them through the engine, `cmd.engine.var.*`, WI-0050; it holds no copies) |
| Variables `global`/`static` (working copy) | engine: `EngineVars` (WI-0040); `VarLoader` loads, `VarWriter` writes through `storage` (WI-0041) | the files `Variables/` (storage) |
| Variable files on disk | storage | – (write-behind from the engine) |
| Parse cache of expression trees (`src/expr/`, up to 2000 texts, doc/EXPRESSION-LANGUAGE.md section 12) | the process that evaluates (engine, worker): a local cache of immutable trees, no state that anyone else reads | – |
| Flow files, backups | storage | – |
| Settings (runtime) | engine | everyone as read-only copy via `evt.settings.changed` |
| Settings (file) | storage | – |
| Trigger handles (hotkey, hook) | triggerhost | engine only knows the target state |
| Process list, restart counter | supervisor | – |
| Diagnostic data of a process (ring buffer of log, last unhandled errors, counters of peer and connection) | the process itself; others receive a copy via `cmd.diag.snapshot` (section 6.2, PROTOCOL 4.9) | `debug`, crash report |
| Output buffer of the children (stdout/stderr, also of ended ones), ring of `evt.diag.error`, events of the topic `process`, reports not yet written | supervisor | crash report |
| Report folder `Reports/` | storage (sole writer; the supervisor only supplies the content) | – |
| Language texts | each role loads `assets/language/<folder>/<code>.ini` and `src/elements/<package>/language/<code>.ini` itself, read-only (`LangTable`, WI-0042, WI-0047) | – |

### 4.1 State changes are events

UIs render what the engine reports. An editor does not mark an element as "running" itself; it receives `evt.element.state`. A newly connected or restarted client fetches the actual state via `cmd.engine.snapshot` (resync); afterwards events follow with increasing `seq`.

### 4.2 Editing model (D0010, E0001)

- v1 behaves like this **[V1]**: the editor changes the "current state" of the flow directly in shared memory, and execution reads the current state at each step. Changes during execution therefore affect the following steps.
- **Decision E0001 (2026-10-11): changing during execution is allowed** (observable v1 behavior). The engine uses the **latest committed revision** of a flow at each step. Implemented in WI-0021: a run (`Executor._NewRun`) only stores the `flowId`. Each step (start of an element, selection of the next connection) fetches the definition via `Executor._DefOf` from the engine's `FlowTable`. A new revision (`FlowRecord.Commit`) therefore applies to all running instances at their next step. Class and parameters of a running element are in `run["active"]` and remain those from the start.
- v2 keeps this observable behavior, but without shared memory: after each completed user action (mouse release, dialog OK) the editor sends a **patch** `cmd.flow.patch {flowId, baseRev, ops}`. The engine applies it atomically, increments `rev` and answers with the new `rev`. The engine reads the latest committed revision at each step. Every revision is an immutable snapshot; there are no half-written states.
- On a `baseRev` conflict (e.g. the manager has renamed something), the engine rejects and sends the current state. The editor merges again.
- View-only changes (zoom, offset) belong to the editor and are written along as `flowSettings` with "Save".
- Saving is an explicit command: `cmd.flow.save`. The engine hands the snapshot to `storage`, `storage` writes atomically (temp file + rename) and reports `evt.flow.saved`.

**Semantics for changes during execution (target state after WI-0021).** Reconciled with v1 (`v1/Source_Execution/Execution Task/Execution Task.ahk`, lines read from the code, not executed). Deviations from v1 are in [MIGRATION.md](MIGRATION.md) (M-0017, M-0018).

| Case | Behavior in v2 | Behavior in v1 |
|---|---|---|
| Running element (`running`) whose parameters or class are changed | runs to the end with the class and parameters it was started with; `Element_stop` with the same values | Parameters are copied at start (`:72`) and executed and stopped from the copy (`:246`, `:211`). The class for `Element_stop` however comes from the current state (`:198`), see M-0018 |
| Thread waits (`ready`, v1 `starting`), element is changed | starts with the values that apply at the moment of start | reads class and parameters at start from the current state (`:67`, `:72`) |
| Next connection after the end of an element | from the latest revision | `:110`, `:115`, `:138` read the current state |
| Thread waits (`ready`), next element was deleted | ends with result `exception`, message "element was removed", `f1` log. No dialog from the engine. Deviation, see M-0017 | `:67` returns an empty element, `:71` sets the thread to `running`, `:88`–`:94` finds no function and calls `MsgBox`, inside the critical section. No task is queued, the thread stays `running` permanently (assumed that access to a property of the empty value throws no error, not executed) |
| Running element is deleted | runs to the end. Afterwards it finds no connection, the thread ends. The message names the element ID and the name from the start (M-0018) | `:110` returns no element, `:153`–`:166` end the thread. The name in the `f0` log remains empty (`:161`, assumed) |
| Flow is deleted | all instances are stopped (reason `flow.deleted`, `Executor.FlowDeleted`). The stop waits for no acknowledgement (`Executor._StopRun`), so the deletion cannot fail on a deadline. If a flow disappears from the table without `FlowDeleted` having run, the next step of the instance stops it with the same reason | `DeleteFlow` stops all instances (`Manage Flows.ahk:190`, `Instances and Threads.ahk:165`–`:188`), waits at most 10 s, otherwise it aborts and does not delete (`Manage Flows.ahk:192`–`:206`). v1 has no reason for this. In v2 there is no deadline and no abort: deleting without a deadline is **confirmed** by the project owner on 2026-10-12 (E0009). Instances stop immediately; a blocking worker is terminated by the pool after `WorkerBridge.ORPHAN_MS` (2 s) |

### 4.3 Outlook: debugger (E0001)

The debugger is **not** built in Phase 2b. However, the following requirements must not be blocked by later designs:

- An **execution gate** in the dispatcher of the engine: before each element, execution can be paused per instance or flow (pause, breakpoint on an element, single step, artificial delay after each element, e.g. 3 s). Pausing takes effect at element boundaries; a running element (especially in the worker) runs to its end.
- During a pause, clients can read and change all variables of an instance (messages to the engine; the engine owns the variables, section 4). The messages exist since WI-0050: `cmd.engine.var.*` with `instanceId` and optional `threadId` (PROTOCOL 4.5); the flow runner of the tests uses them.
- Editing during a pause takes effect at the next step (follows from E0001 and the table in 4.2).
- The events for this (e.g. `evt.instance.paused`) and commands (`cmd.debug.*`) are designed in Phase 3 or later.

---

## 5. State machines

Invalid transitions are **not** executed, but rejected with an `a0` log. The tables are normative.

### 5.1 Instance (`instance`)

| From | Event | To | Action |
|---|---|---|---|
| (new) | `flow.start` or trigger accepted (according to execution policy) | `running` | create thread for trigger element |
| (new) | policy `skip` and flow is running | (rejected) | callback "skipped" |
| (new) | policy `wait` and flow is running (E0002, M-0011) | `waiting` | enqueue in the flow's queue (FIFO), `evt.instance.queued`, response `waiting: true` |
| `waiting` | no started instance of the flow anymore (the previous one is `ended`) and the instance is the first in the queue | `running` | create thread for trigger element, `evt.instance.started`. If the flow or the trigger is missing by now, the instance ends without `started` (reason `flow.deleted` or `trigger removed`) |
| `waiting` | `flow.stop` / flow deleted | `ended` | remove from queue, `evt.instance.ended`. The instance has no thread |
| `running` | last thread removed | `ended` | remove instance, recalculate `flow.executing` |
| `running` | `flow.stop` / policy `stop` / `x_InstanceStop` | `stopping` | all threads `stopping`. Waiting instances of the flow are ended beforehand |
| `stopping` | all threads removed | `ended` | callback "stopped" |
| `stopping` | deadline (2 s) without acknowledgement | `ended` | terminate worker hard, log. The instance ends immediately; the engine requests the hard termination of the worker from the supervisor (`cmd.process.kill`, section 6.4), it terminates no process itself |
| `ended` | any | – | ignore (log) |

### 5.2 Thread (`thread`, states as in v1: starting, running, finished, stopping **[V1]**)

| From | Event | To | Action |
|---|---|---|---|
| `ready` (v1 `starting`) | dispatcher selects thread | `running` | start element (inline or worker) |
| `running` | `ctx.Finish(result, msg)` | `finished` | save result, update counter and state of the element |
| `finished` | matching connection found | `ready` | set next element, clone thread if there is more than one connection |
| `finished` | no matching connection | `removed` | for result `exception`: log as unhandled and report |
| `running` | stop of the instance | `stopping` | call `Element_stop` or cancel worker |
| `stopping` | stop acknowledgement or deadline | `removed` | – |
| `ready` | stop of the instance | `removed` | – |
| `finished`/`stopping`/`removed` | late `Finish` | (none) | ignore, `f2` log (corresponds to v1) |

The selection of the next connection follows v1 exactly: connection type equals result, and for loops additionally `fromPart` **[V1]**. Loop variables are pushed onto a stack on entry and restored on exit (`tail`/`exception`) **[V1]**.

### 5.3 Process (monitored by the supervisor)

`starting` → (`sys.hello`) → `ready` → (`sys.shutdown`) → `stopping` → `exited`. Deviations: `hung` (ping timeout), `crashed` (process gone or pipe broken). See 6.2.

---

## 6. Flow, errors, shutdown

### 6.1 Startup

1. Entry `AutoHotFlow.ahk` (role `supervisor`; the other roles start from `entry/<role>.ahk`, D0012). A named mutex ensures a single instance. If an instance already exists, the call forwards command-line commands (v1: `AHFCommand`) to it via pipe and ends.
2. Supervisor creates the hub pipe and starts `storage`. `storage` reports `sys.hello`, loads settings and the directory index.
3. Supervisor starts `engine`. The engine fetches settings and all flow files via `storage` (responses, never blocking), loads them into memory and reports `evt.engine.ready`. The engine reads the files **staggered**: at most `Engine.LOAD_PARALLEL` (2) `cmd.storage.flow.read` at the same time; the next request goes out only after a response has been processed (WI-0024). Reason: each response costs the engine the parsing of the whole flow text (about 0.3 s for 93 KB); if all responses came at once, a `sys.ping` would wait behind all of them and the supervisor would consider the engine hung. If `storage` does not respond (timeout, connection gone, no peer `storage`), the engine requests no further file and also reports no error. **The engine waits for `storage` (WI-0031, F-0027, F-0021):** it subscribes to the topic `process` and then asks `cmd.process.list`; as soon as `storage` is `ready` there or `evt.process.ready` arrives with name `storage`, it starts loading. If `storage` is not there yet, it asks again at an interval of 1 s, without an upper limit on attempts, without `evt.storage.error`, and with at most one log line (`a1`) per 30 s. If loading aborts, it likewise waits again for `storage`, fetches the list anew and reads only the files that have no result yet (loaded, or a real read or parse error); already loaded flows remain. `evt.engine.ready` comes only when every file of the list has a result **and the variables are loaded (WI-0041):** after the flow files the engine loads all `global` and the `static` variables of the loaded flows through `cmd.storage.var.list` and `cmd.storage.var.get`, staggered like the flow files (at most 2 requests at the same time) and with the same waiting for `storage` after an abort (PROTOCOL 4.6). Reason: an expression reads variables synchronously, so they must be in memory before a flow runs; loading on demand would only work by blocking. Routing in the hub reads only the header fields for such frames (PROTOCOL 2).
4. Supervisor starts `triggerhost`. The engine sends `cmd.trigger.arm` for the triggers of active flows. Errors per trigger are reported back; they do not prevent startup.
5. Supervisor starts `manager` (except with `--background`). **Only the manager has a tray icon (E0046, corrected 2026-10-15):** every entry script carries `#NoTrayIcon` except `src/entry/manager.ahk`, so the supervisor and all other roles start with the icon hidden, and so does every process of a test run (the test entries, the test-entry manager included). The stub manager keeps the icon until S0004 gives it the real one (REQ-MGR-090: exactly one icon; the menu and the "end" action come with S0004). Closing a window or ending a role from outside is classified as before (a role closed by its X button is an unexpected end).
6. Each step has a timeout (default 10 s). If a mandatory process fails, the supervisor reports this via log (and, once the tray icon exists again, via tray notice) and ends the session cleanly.

### 6.2 Error handling

| Scenario | Detection | Reaction |
|---|---|---|
| Child process crashes | process handle signaled or pipe broken | supervisor logs, restarts according to policy (max. 3 attempts in 60 s), reports `evt.process.crashed` |
| Engine crashes | as above | restart. Running instances are lost (documented in [MIGRATION.md](MIGRATION.md)). Clients receive `evt.engine.restarted {epoch}` and resynchronize. Triggerhost is re-armed. |
| Process hangs | no `sys.pong` for 3 consecutive pings (2 s each) | supervisor sends `sys.shutdown`, after 2 s `TerminateProcess`, then as with a crash. If an editor hangs, only its window is affected. |
| Supervisor stood still (frozen, standby, backlog) | gap between two ticks longer than 2 s (`Stall.MIN_GAP_MS`). **One** place measures this: the start of `Supervisor._RunTick` (`Stall.Check`), before any evaluation by the clock (WI-0033, F-0015, E0012) | The length of the standstill (gap minus one regular tick) is reported to all deadline holders; each deadline is pushed back by this time and thus keeps its remaining time (log `a1` "supervisor stood still for N ms, deadlines extended"). No child is judged by old timestamps: pong/ping time and startup deadline of all children begin anew at "now" (`Children.ResetLiveness`); kill time of a hanging child, time of a planned restart and grace period of an ended process are shifted by the length (`Children.OnStall`). Requests of the hub (`Hub.Request`, e.g. `cmd.app.prepareExit` with 10 minutes) and the `sys.hello` deadline of new connections are shifted (`Hub.Shift`), likewise the deadline and kill wait time of the shutdown (`Shutdown.Shift`) and a report's wait for `storage` (`DiagReport.Shift`). A truly hanging child is found one pong deadline later. The children do not give up during the standstill (their orphan guard only triggers on a broken pipe). **Requests of the hub are no longer `SetTimer` timers, but a deadline list that the tick checks** (`Hub.Tick`, precision one tick, 200 ms): a `SetTimer` that became due during the standstill could run before the tick that notices the standstill, and expire the request immediately. Deliberately not shifted: the window of the restart history (60 s, a rate over real time), the minimum interval of automatic reports, the window of the error count. The deadlines of the roles (`Peer.Request` via `SetTimer`) all expire at once after a standby of the machine: response `timeout`, the caller retries (watch list). |
| Engine ends (crash, restart limit, end outside of session shutdown) | process handle of the engine signaled (`Children.Tick`) | The supervisor immediately terminates all living `worker:*` (E0010, WI-0033): `evt.process.exited {reason: "engine gone"}`, not `crashed`, not for exit code 5, no restart. They do not wait for the evaluation of the engine's end. When the session ends, the order of ranks applies (6.3). |
| Log of the supervisor | the supervisor has no peer | `DiagLog` sends its entries as `evt.log.append` via the hub to `storage`, queued beforehand (max. 500), which is emptied on `sys.hello` from `storage`. Even without stderr (double-click start), every message of the supervisor remains in `Log/Log.txt`. |
| Output of a child (stderr, load errors, last words) | the supervisor starts children with `CreateProcessW`; stdout and stderr point to an anonymous pipe (`ChildLauncher`); each tick reads it without blocking (`ChildPipe`, `PeekNamedPipe`) | Each line becomes a log entry (`a0`, source = role, text `[<Name>] <line>`) and goes via `DiagLog` to `storage`. Per child, the last 100 lines remain in memory, also after the process has ended (`Children.Output`, basis of the crash report, WI-0028). At the end the remainder is read, then the handles are closed. Per tick at most 64 KB read and 200 lines logged; the rest only in the ring buffer. Only the writing end of the pipe and `NUL` are inherited (`PROC_THREAD_ATTRIBUTE_HANDLE_LIST`), not the hub pipe. |
| Messages that are too much for diagnosis | `--log-level=<0..3>` (default 2) | Only entries up to this digit go to `storage`. The last 500 entries of all levels remain per process in the ring buffer of `Log` (for the crash report). |
| Unhandled error in a role (no `try/catch`) | `OnError` of the role (`Role._OnUnexpected`) | The role counts it, sends `evt.diag.error {name, errorType, message, file, line, stack, mode}` to the supervisor (log `a0` and ring of the last 50) and continues running. More than 20 in 60 s: exit code 6 "too many unexpected errors"; for `engine` and `storage` the restart rule applies afterwards. |
| Snapshot (WI-0028) | every role answers `cmd.diag.snapshot` (PROTOCOL 4.9): general part from `Role.Snapshot` (process, memory, handles, peer counters, log ring, last unhandled errors), role part from the hook `Role.DiagInfo()`. The supervisor answers it itself (process table with restart history and exit codes, hub connections and queues, output buffers of the children). Never contents of variables or flows. | The answer comes from the running process. A frozen process does not answer; the caller notices this at its deadline |
| Crash report (WI-0028) | `cmd.diag.report {reason}` or automatically on: child ended unexpectedly (`crashed`), restart limit reached, `hung`, 10 unhandled errors of a role in 60 s | The supervisor asks all connected roles simultaneously for the snapshot (deadline 2 s per role; missing answers are noted in the report), adds its own snapshot including output buffers of dead children, and sends `report.json` and `summary.txt` to `storage` (`cmd.storage.report.write`), which writes `Reports/<yyyyMMdd-HHmmss>_<reason>/`, copies the latest log files and keeps 20 reports. Automatically at most one per minute, none during shutdown. If `storage` is not there, the report waits up to 10 s in the supervisor's memory; afterwards it is written on the next connection of `storage`. The supervisor never writes files itself |
| Request without response | timeout of the correlation ID | caller receives `res` with `error.code = "timeout"`, never an endless wait |
| Target of an open request goes away (dies, pipe breaks) (WI-0034, F-0036) | The hub remembers forwarded `cmd.*` (header fields) until the response; the connection of the target ends | The hub immediately answers the sender with `peer_gone` (PROTOCOL 2), not only when the sender's deadline expires. Measured 0.07 to 0.15 s instead of the deadline (10 s in the test, 30 s when loading the engine). The roles need nothing for this: `peer_gone` is a normal error response. Exception: the engine's worker pool treats `peer_gone` on `cmd.worker.run` as loss of the worker ("worker crashed", F-0042, WI-0035), because the response arrives before the supervisor's process event |
| Pipe breaks | `ERROR_BROKEN_PIPE`/`NO_DATA` | client attempts reconnection (backoff 100 ms to 2 s, max. 10 s), afterwards the role terminates itself |
| Worker fails | process gone (`evt.process.crashed`/`exited`) or `peer_gone` on the open `cmd.worker.run` (the hub answers up to one tick before the process event; both paths apply equally, their order is open, F-0042) | Engine reports the thread `exception` with text "worker crashed", removes the slot and starts a replacement if needed (6.4). Storm limit: 5 abnormal ends in 60 s, then "worker not available" |
| Worker blocks for a long time (download, COM, `DllCall`) | the worker reports job start and end (`sys.busy`) | A busy worker is not pinged and never terminated as hung. It ends only through its element, through cancellation (deadline 2 s, then hard termination) or through the job deadline of the element (6.4) |
| Engine restarts | new engine epoch | The supervisor has already terminated the workers of the old engine (line "Engine ends"). The new engine nevertheless terminates all remaining `worker:*` (second safeguard, `WorkerBridge.Start`) and rebuilds the pool (6.4) |
| Element blocks the engine | watchdog: element call > 250 ms (warning), > 5 s (error `f0`) | Note with class and flow; the classification `inline` must be corrected |
| Element code throws | `try/catch` around each call | thread result `exception` with message (like v1 `finishExecutionOfElement(..., "Exception", msg)`) |
| Invalid state transition | state machine | rejected, `a0` log with context |
| File not writable | `storage` reports error | `evt.storage.error`, engine keeps working copy, UI shows notice. Never a dialog from the engine. |
| Unknown message | dispatcher | `res` with `error.code = "unknown_type"`, logged |

### 6.3 Shutdown

Two phases, so that user decisions do not run into hard timeouts:

1. **Prepare (abortable, no hard deadline):** supervisor sends `cmd.app.prepareExit` to editors and manager. An editor with unsaved changes asks the user. The user can cancel; then the process ends and nothing was stopped.
2. **Shutdown (hard deadline, default 5 s total):** supervisor sends `sys.shutdown {deadlineMs}`. Order of acknowledgements: editors/manager/debug window (rank 0, `cmd.app.prepareExit` only to editors and manager), engine (stops instances with 2 s each, then sends the variables that are not written yet to `storage`, WI-0041), triggerhost (deactivates all triggers), workers, finally `storage` (empty queue). Each process acknowledges with `sys.bye` and terminates itself.
   - **The role flushes before ending (WI-0030, F-0023):** `sys.bye` is the last message of a role; everything sent before it (events of the stopped instances, `evt.worker.done` "stopped", log lines, in Phase 3 the variables to `storage`) is in the same send queue ahead of it. The role closes its connection with `Peer.CloseWhenFlushed` instead of `Close` (`Close` discards the queue): no new frames, the queue continues to be written via timer, and it is closed when empty, at the latest after the rest of the deadline from `sys.shutdown`, at most 1000 ms (`Role.FLUSH_MAX_MS`), at least 50 ms. Only then `ExitApp`. No `FlushFileBuffers` (waits without deadline for the reader). When the hub is lost (`Role._Exit`) there is nothing to flush; the role ends immediately. If it ends with a connected peer (too many errors, exit 6), it flushes at most 500 ms.
   - **The supervisor evaluates after the last byte (WI-0030, F-0023):** An ended process is evaluated as `exited`/`crashed` (and `clean` is determined) only when the hub has read its connection to the end (the connection is gone, `Hub.HasLink` false), or 500 ms after the process end (`Children.EXIT_GRACE_MS`), if the child never connected or the connection does not end. Reason: `hub.Pump()` before `children.Tick` (F-0010) is not enough if the tick interrupted a running pump of the same connection; that pump's guard against re-entry makes the tick's pump return immediately. So that reading to the end also succeeds when the hub has written to the already ended child beforehand, a write error "peer gone" in `PipeConnection` closes only the write side; reading continues to the end of the data stream (at most 1 s). Until evaluation the state stays unchanged; the child counts in this time neither as hanging nor is it terminated hard (`Terminate` checks the process end). `evt.process.exited`/`crashed`, the end of a group during shutdown (if no `sys.bye` came) and a restart are delayed by at most this grace period, normally by no tick.
   - **A child reports itself during shutdown (WI-0034, F-0037):** `sys.shutdown` is sent to the children of a group once, when the group is its turn. A child that starts only then (the warm worker, an editor, the debug window) and says `sys.hello` only afterwards would otherwise never receive it: its group and all later groups, finally `storage`, would wait until the deadline, and `storage` would be terminated hard (exit 5; the queue of `storage` would be lost). Therefore `Shutdown.OnHello` (called by `Supervisor._OnHello`) in phase `shutdown` immediately sends `sys.shutdown` with the remaining deadline upon `sys.hello`, if the child's group was already or is currently its turn, and also if the child is in no group (its process came into being when the groups were formed). A child of a later group waits for its group (normal order). In phase `prepare` the groups form later and contain the child; in phase `kill` `KillAlive` has already terminated it. The hard deadline does not change. A child that has never connected (state `starting`) does not hold its group (`Children.GroupDone`, F-0039): it is handled when it says `sys.hello` (`Shutdown.OnHello`), or ended at the deadline, so a slow starter can no longer cost `storage` its `sys.shutdown`.
   - **Planned restarts are dropped (WI-0034, F-0037):** A crash of `storage` or `engine` shortly before shutdown begins plans a restart (`RESTART_DELAY_MS`, 300 ms). `Children.BeginShutdown` cancels it, otherwise the process would come into being in the middle of shutdown in no group. New children otherwise do not come into being during shutdown: `cmd.process.spawn` and `cmd.app.command debug` throw `shutting_down`.
   - **Open requests to a gone target (WI-0034, F-0036):** If a child goes away during shutdown (or otherwise), the hub immediately answers the open forwarded requests with `peer_gone` (6.2, PROTOCOL 2). `peer_gone` means "outcome unknown"; whoever waits for a response during shutdown (e.g. the engine for `storage`) no longer waits until its own deadline.
3. After the deadline, the supervisor terminates remaining processes hard. Exit code 5 applies only if a process was really terminated in the process (`Children.AnyKilled`, WI-0033, F-0029): a process that ended itself at the deadline and is evaluated only in the grace period does not make the exit forced. The deadline and the wait time after the hard termination are pushed back during a standstill of the supervisor (6.2). This is harmless, because there is no shared lock and `storage` writes atomically (temp file + `MoveFileEx`).
4. **Orphan guard:** every role checks every 2 s whether the supervisor is still alive (pipe). Otherwise it terminates itself after 3 s. **Exception (F-0025):** a role that has never been welcomed by the hub (peer status `connecting`, because the hub's pipe does not exist yet or is busy) is not covered by this guard. It ends when the reconnect budget of its peer is used up, `Peer.DEFAULT_RECONNECT_TOTAL_MS` (10 s, counted from `Connect`), with exit 4 `hub_unreachable`. A child that is still starting can therefore live up to 10 s after its supervisor has died (measured: 10.2 s, commit 4d97c49). Accepted by the project owner on 2026-10-13 as low impact. The same budget applies when the hub accepts the pipe but never answers `sys.hello`: a failed hello does not restart the budget (`Peer._BeginReconnect` keeps `_budgetStart` when the connection ended in `handshake`), so the role ends by the same deadline with exit 4 (test `test_hub_that_never_answers_hello_ends_the_role_with_exit_4`; the budget is counted from `Connect`, or from the loss of a ready connection). At system shutdown (`WM_QUERYENDSESSION`) the supervisor starts step 2 immediately.

The v1 mechanism `criticalSectionCounter` and the 4-second `exit` emergency brake are dropped.

### 6.4 Worker pool (E0003, WI-0027)

The owner of the pool is the **engine** (`WorkerBridge`): it knows which jobs are running and holds all deadlines. The **supervisor** owns the processes: it starts and terminates workers only on request of the engine (`cmd.process.spawn`, `cmd.process.kill`, rights in PROTOCOL 4.1) and monitors them like any child. It knows neither jobs nor pool sizes. The worker itself reports only whether it is busy.

| Size | Value | Engine option | Rationale |
|---|---|---|---|
| Upper limit N | 4 (0 to 8; 0 = no pool) | `--workers=<n>` | A worker costs about 14 MB and 30 ms startup time (measurement of the spike); four simultaneously blocking elements (dialogs, downloads) cover the usual flows. The supervisor additionally never allows more than 16 living workers (protection against a faulty engine) |
| Warm workers W | 1 (0 to N) | `--warm-workers=<w>` | The first worker job should not wait for a process start |
| Idle time | 60 s (100 ms to 1 h) | `--worker-idle-ms=<ms>` | A dialog flow often returns after seconds; an idle process costs only memory |
| Storm limit | 5 abnormal ends in 60 s | – | see below |
| Confirmation of cancellation | 2 s (`WorkerBridge.ORPHAN_MS`) | – | as 5.1 |
| Acceptance of a job | 5 s (`ACK_TIMEOUT_MS`) | – | unchanged |
| Job deadline | none, unless the element class sets `JobTimeoutMs` | property of the element class | v1 had no deadline; a dialog may stay open arbitrarily long |

**Slots.** The engine keeps a list of slots with the states `starting` (start requested, no `evt.process.ready` yet), `idle` and `busy`. There is no state `down`: a worker that fails or is terminated disappears from the list. Slots and still open start requests together are never more than N.

**Demand.** If at least one thread waits for a worker (state `ready`, no slot `idle`), the engine requests as many workers as threads are waiting, minus those already starting, at most up to N. At engine start (after cleaning up orphans) W workers are requested. The thread waits in `ready` as before; the dispatcher runs as soon as a slot becomes `idle`.

**Idle.** An `idle` slot that has been unused for longer than the idle time is terminated (`cmd.process.kill`, reason `idle`), as long as at least W workers remain afterwards. Warm workers keep running.

**Crash.** `evt.process.crashed` or `evt.process.exited` for a slot, or `peer_gone` as the response to the open `cmd.worker.run` (F-0042, WI-0035; whichever comes first ends the job, the second finds neither slot nor job): remove the slot; a running job ends with `exception` "worker crashed (worker:n)". The supervisor never restarts workers itself (`Children.AUTO_RESTART`). If workers are then missing (demand or W), the engine requests new ones. **Storm limit:** a crash, a start that never became ready (the supervisor reports "hung"), a rejected `cmd.worker.run` and a failed start request count as abnormal ends. With 5 of them within 60 s, the engine requests no more workers until the oldest end leaves the window. If no worker is alive then, waiting and new worker elements end with "worker not available", and the engine writes `a0` "worker pool blocked" once. Normal growth and shrinkage of the pool does not count, only errors (deviation from the wording "5 starts in 60 s" in WI-0027: a burst of four simultaneous jobs starts four workers and is not a storm).

**End with the engine (E0010, WI-0033).** If the engine process ends (crash, restart limit reached, end outside of session shutdown), the supervisor immediately terminates all living `worker:*` (`Children._EndWorkersOfGoneEngine`): nobody accepts their result any more, and a worker with an open dialog would otherwise remain until the end of the session if no new engine comes. The end is reported like `cmd.process.kill`, as a planned end: `evt.process.exited {reason: "engine gone"}`, not `crashed`, not for exit code 5, no restart. A worker whose process had already ended before (handle signaled, end not yet evaluated) is not relabeled: its end remains a `crashed` (F-0042, WI-0035); the same applies to `cmd.process.kill` (`Children._HasEnded`). The supervisor reacts as soon as the process handle of the engine is signaled (in the same tick), not only after the evaluation of the engine's end. When the session ends, the order of ranks remains. The new engine rebuilds its pool (demand, warm workers); `WorkerBridge.Start` terminates whatever else it still finds (second safeguard).

**Busy and ping.** When a worker accepts a job, it sends `sys.busy {busy: true}` to the supervisor before the element starts, and `busy: false` when the job ends (`done`, `stopped`). While a worker is busy, the supervisor sends it no ping and does not evaluate any pong. When the busy state ends, the pong times begin anew. The process handle still applies: a worker that dies during a job is detected as crashed immediately. **Reason why the worker reports and not the engine:** the fact "this process is currently running a job" belongs to the worker (one owner per datum, section 4). The message goes by the shortest route and before the element starts; it needs no coordination between two connections (engine → worker and engine → supervisor are not ordered); and it remains correct when the engine is just restarting. There is no gap in which the worker blocks without being reported as busy: the message happens in the handler of `cmd.worker.run`, before the element starts.

**Cancellation.** If an instance stops a worker element, the thread ends immediately (as with inline), and the engine sends `cmd.worker.cancel`. If no `evt.worker.done` arrives within 2 s, the worker is blocked: the engine removes the slot and requests `cmd.process.kill` (reason `cancel not confirmed`). A worker that confirms the cancellation remains in the pool.

**Job deadline.** If the element class has `JobTimeoutMs` > 0, the engine starts a clock with the job. If it expires, the thread ends with `exception` "worker timeout", and the job is treated like a cancellation (cancel, after 2 s hard termination). The engine holds the deadline, not the worker, because the worker may be blocked.

**Restart of the engine.** On start, the new engine (`OnReady`, before it requests workers itself) asks `cmd.process.list` and terminates all `worker:*` that do not belong to it (`cmd.process.kill`, reason `orphan of a previous engine`). Adopting them would be unsafe: the state of the jobs (variables, instance) is lost, and their results could not be assigned. A late `evt.worker.done` from an orphan is discarded (unknown `execId`). If the query fails, the engine builds the pool anyway and logs `a0`; the orphans then keep running until the end of the session. Between the death of the old engine and the start of the new one the orphans stay alive (restart delay 300 ms plus startup time).

**Shutdown.** On `sys.shutdown` the engine requests no more workers and terminates none. The workers follow in rank 3 (6.3). A busy worker reports `stopped` before `sys.bye`. After shutdown has begun, the supervisor rejects `cmd.process.spawn` with `shutting_down`.


---

## 7. Compatibility with v1 files

Checked against the 23 flows in `v1/AppData/Saved Flows` and `Save.ahk` **[V1]**:

- Flow file: JSON, UTF-8 without BOM, indentation 2. Root keys: `name`, `category` (as **name**, not ID), `ElementIDCounter`, `flowSettings`, `allElements`, `allConnections`.
- Elements have `ID`, `type`, `class`, `x`, `y`, `name`, `StandardName`, `pars` (only the parameters declared by the class), `package`, `packageVersion`, optionally `HeightOfVerticalBar` (loop), `DefaultTrigger` (`trigger_manual`), `enabled` (trigger).
- **`package` and `class` are the identity of an element (E0045, WI-0047):** v2 looks an element up by both, as the qualified ID `<package>.<class>` (`Default.Action_Sleep`), without regard to case (v1 wrote `package` for 1077 of 1077 elements of the test flows, 8 of them as `default`). A missing or empty `package` means `Default`. The keys are not changed when a flow is saved. An element of a package that is not installed (an extension package of v1, REQ-PKG-020) loads like an element of an unknown class: its texts and keys stay, a save writes it back unchanged (with `v1Text` in a file of v1 origin), and when it runs it ends with `exception` "element class '<package>.<class>' is not available: package '<package>' is not installed" (an unknown class of a known package: "unknown element class '<package>.<class>'").
- Connections have `ID`, `from`, `to`, `type`, `ConnectionType`, optionally `fromPart`/`toPart`.
- **Values are stored mixed as JSON string and JSON number.** In the 23 sample files there are 17,453 strings and 703 numbers (e.g. `"ElementIDCounter": "5"` and `"zoomFactor": "0.700000"` as strings, `"DelimiterComma": 1` and `"x": 7` as numbers). `true`, `false` and `null` do not occur. v2 must preserve the type of each value (AHK v2 distinguishes `String`, `Integer`, `Float`, which makes this possible). Round-trip tests compare parsed structure and types.
- A key `CompabilityVersion` does not occur in the existing files. According to `Compatibility.ahk`, a missing value equals "oldest version" (v1 hooks are empty). The hook structure (`package`-specific function) is preserved.
- Variables: global ones under `<data directory>/Variables/<name>.ahfvd`, static ones under `<data directory>/Variables/<FlowID>/<name>.ahfvd` (e.g. `Flow 1010290492`). `.ahfvd` contains JSON metadata `{name, type}`, `.ahfvar` the content (JSON for `type=object`). v1 writes UTF-8 with BOM; v2 reads both and writes without BOM (WI-0041, M-0006).
- Export/import `.ahf` is a ZIP (7z). Preserved.
- The backup behavior (up to 10 files, `backup/` subfolder) remains.

Unknown items in files (keys that v2 does not know) are **kept when loading and written back when saving**, so that switching between v1 and v2 loses nothing.

**Format version and conversion of expression texts (WI-0039, E0021, E0022).** v2 reads old flows unchanged and converts the expression texts on load (doc/EXPRESSION-LANGUAGE.md section 15). So that a text is never converted twice and no v1 text stays unconverted for ever:

- A file written by v2 has the root key `"formatVersion": 2`. A file without it comes from v1; all its elements are candidates for the conversion.
- Which parameters of an element are expressions, only its class knows (`Parameters()`: content type `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger`, `positiveIntegerOrZero`, or the type selected by the user in the parameter named by `contentID`; plus `static V1Syntax` for parameters that the element evaluates itself). The engine converts on load, using the element registry.
- An element whose class is not in the registry (in S0001 to S0007 most of them, E0020) keeps its v1 texts. A save writes it with `"v1Text": true`. In a file with `formatVersion` only elements with this marker are converted, as soon as their class is known; the marker is removed in memory at that moment and not written again.
- The two keys are not part of the definition in memory (`FlowDefinition.Raw`); `FlowDefinition.Pending` names the waiting elements and `FlowDefinition.ToFileText()` writes the keys. A save with `cmd.flow.save`.
- **Migration markers (WI-0045, E0035):** an element with at least one parameter text that behaves differently in v2 (a class of the deviation catalog, doc/EXPRESSION-LANGUAGE.md section 15.1, that the text itself shows; or syntax that is not supported; or a text that the new language cannot read) carries the key `"migration"`: a list of `{"par": <parameter ID>, "ids": ["M-0025", ...], "v1": <the v1 text before the conversion>}`. The IDs are entries of doc/MIGRATION.md (the mapping is `MigrationClasses`, `src/expr/MigrationClasses.ahk`; the detection is `V1ExprDetect`, reported by `V1ExprConverter.Convert` in `conv["classes"]`). Only what the text shows is marked; where the result depends on a value known at run time nothing is marked. The key is an ordinary key of the element: it stays in `Raw`, is written back and sent to clients, stays until the place is resolved (editor or AI-assisted import, not part of S0002), and a parameter that is listed is not listed again, so load, save, load is stable and the v1 original is never overwritten. `python tools/migration_report.py <flow file or folder> [--json]` (VS Code task `Tool: migration report of a flow folder`) lists, per flow, the elements of unknown class and the marked places; it runs the loader through `tools/ahkrun.py`. An element whose class is unknown has no `migration` key (its texts cannot be examined); it keeps `v1Text`, and its places are found when the class appears.
- The conversion of a flow is idempotent: loading a file that was saved by v2 changes no text. This is the version marker that E0008 announced; apart from the two keys (and `flowSettings.strictTypes`, below) the format is the v1 format.
- **Flow option `strictTypes` (E0034, WI-0042):** `flowSettings.strictTypes` (JSON `true`/`false`) says how a type error of an evaluation is handled (a comparison or calculation with a text that is not a number, doc/EXPRESSION-LANGUAGE.md section 17). `false` is the compatibility mode: the result is the empty text plus an `f1` warning (E0025), as in v1. `true` is the strict mode: the element ends with `exception` (ELEMENT-API-V2 section 3.1). A flow without the key is a migrated one (a v1 file, or a file that v2 saved before the option existed) and gets `false`; a flow that v2 creates gets `true` (`FlowDefinition.NEW_FLOW_STRICT_TYPES`, for `cmd.flow.create` in S0004). The engine keeps the mode in `FlowDefinition.StrictTypes` (Raw is not changed, so `cmd.flow.get` shows the key only when the file has it); a save always writes the key, so the mode of a flow never changes by itself. Showing the warnings in the editor: S0004/S0005.

**Decision E0008 (2026-10-11):** Truth values go as real JSON booleans over the wire in v2 (WI-0026). The flow file format may in future differ from the v1 format in v2. The requirement remains that old flows and variables load. In Phase 2b the **write format of the flows does not change**. A new write format is a separate decision in Phase 3, with a version marker in the file. **Update (E0021, WI-0039):** v2 writes the v1 format plus the two keys of the version marker (`formatVersion`, `v1Text`) and the option `flowSettings.strictTypes` (section 7); how v2 saves is otherwise free (E0021). A flow saved by v2 is no longer guaranteed to load in v1.

---

## 8. Folder structure

```
AutoHotFlow/
├─ AGENTS.md                # rules and short state for agents
├─ README.md
├─ doc/                     # permanent documentation (this directory)
├─ work_items/              # temporary: phase 3 working papers (delete after the port)
├─ v1/                      # temporary: unchanged v1 state as reference (delete at the end)
├─ src/
│  ├─ AutoHotFlow.ahk       # entry of the supervisor (includes AhfBoot.ahk and supervisor/, calls AhfMain)
│  ├─ AhfBoot.ahk           # boot code that every role shares: checks, AhfMain, role dispatch (WI-0029, WI-0047-PREP)
│  ├─ entry/                # one entry script per other role: <role>.ahk (D0012)
│  │  └─ generated/         # Elements_<role>.ahk: the element classes of a role, written by tools/gen_element_includes.py (E0041)
│  ├─ core/                 # cross-process building blocks, no GUI
│  │  ├─ Json.ahk  Ids.ahk  Errors.ahk  Log.ahk  Args.ahk
│  │  └─ ipc/               # Pipe, Frame, Wake, Message, Dispatcher, Peer
│  ├─ supervisor/  storage/  triggerhost/  worker/
│  ├─ engine/               # Engine, Executor, WorkerBridge; core/ (flow model, state machines, FlowExprConvert); vars/ (variable model, WI-0040/41)
│  ├─ ui_common/            # GUI helpers (Lang() is in core/, E0028)
│  ├─ manager/  editor/     # editor/render/ = Renderer interface (D0004)
│  ├─ expr/                 # library: expression language (tokenizer, parser, syntax tree, parse cache), doc/EXPRESSION-LANGUAGE.md
│  ├─ debugview/            # role debug (WI-0028): DebugView.ahk, DebugGui.ahk
│  └─ elements/
│     ├─ base/              # AhfElement, ElementRegistry, ElementRunner, ExecContext, ParamEvaluator
│     └─ Default/           # the package Default (E0037): package.json, Actions/ Conditions/ Loops/ Triggers/,
│                           # lib/, language/, Icons/, _includes_<role>.ahk (generated, E0045)
├─ assets/                  # icons, language/<folder>/<code>.ini (the v1 files, WI-0042), help (taken over from v1 once needed)
├─ tests/                   # see TEST-STRATEGY.md
└─ tools/                   # converters, translation tools, audit scripts
```

**Actual state at the end of Phase 2 (WI-0017, compared with the file tree, verified):** The structure above remains the target. Deviations and gaps:

- **Decision E0006 (2026-10-11):** The triggerhost (WI-0014) is built early in Phase 3 with the real triggers, not in Phase 2b.
- Present: `src/AutoHotFlow.ahk`, `src/AhfBoot.ahk`, `core/` (additionally `Role.ahk`, `RoleRegistry.ahk`, `Time.ahk`; `ipc/` additionally `Deferred.ahk`, `PipeConnection.ahk`, `PipeListener.ahk`, `FrameReader.ahk`, `FrameWriter.ahk`), `supervisor/`, `engine/` (with `core/` for state machines, flow model, scheduler), `storage/`, `worker/`, `manager/` (only `StubManager.ahk` and `StubGui.ahk`), `debugview/` (WI-0028, `DebugView.ahk`, `DebugGui.ahk`), `elements/base/`. Since WI-0028, `core/` additionally has `AhfVersion.ahk`, `ProcInfo.ahk`, `Snapshot.ahk` and `Debug.ahk`; `supervisor/` has `DiagReport.ahk`.
- **Not present (Phase 3 or later):** `triggerhost/` (WI-0014 optional, not built; the role is a placeholder, `PlaceholderRole`, registered by `src/entry/triggerhost.ahk`), `editor/` (placeholder role), `ui_common/` (`assets/` exists since WI-0042 and holds only `language/`). Since WI-0047 the elements are in packages: `elements/Default/` (`Actions/Action_Sleep`, `Actions/Action_Do_nothing`, `Triggers/Trigger_Manual`; the folders `Conditions/` and `Loops/` come with their first element), the test elements (`Action_Test*`) in the package `Test` below `tests/elements/Test/`, outside `src/`; they replace the folder `elements/skeleton/` of phase 2.
- `tools/` contains `ahkrun.py` and `ahf_dialogwatch.py` (watchdog), `ahf_dump.py`, `arch_check.py`, `run_suite.py`, `new_workspace.py`, `ahf_processes.py` (lists and ends the running AHF processes; VS Code task `Tool: AHF processes`) and, since S0001, the golden data tools `golden_v1.py`, `golden_corpus.py`, `golden_compare.py` and `golden_classes.py` (doc/TEST-STRATEGY.md section 7). The converter for elements (`tools/convert_element.py`) comes in S0002.
- **Role entries and test entries (WI-0029, WI-0047-PREP):** `src/AutoHotFlow.ahk` (supervisor) and `src/entry/<role>.ahk` (D0012) include `src/AhfBoot.ahk` (the 64-bit check, `AhfMain`, the exit codes) and only the code of their role. `core/RoleRegistry.ahk` registers nothing; each entry registers its role itself, so a process knows only the role it was started for. The element classes of a role are the generated block `src/entry/generated/Elements_<role>.ahk`: `tools/gen_element_includes.py` reads the literal `static Mode := "<inline|worker|trigger>"` of each class file as text (a missing or non-literal Mode fails the generation with the file name) and takes `engine` and `editor` all classes, `triggerhost` the `trigger` classes, `worker` the `worker` classes; `supervisor`, `storage`, `debug` and `manager` no class. The generated blocks are committed; `tests/test_element_includes.py` fails when they are out of date. **Packages (E0037, E0045, WI-0047):** every package is an AutoHotkey class that includes its element files, so the type name of an element is its qualified ID (`Default.Action_Sleep`); the generator writes one block per package and role (`elements/<package>/_includes_<role>.ahk`), and `Elements_<role>.ahk` includes the blocks of all product packages (doc/ELEMENT-API-V2.md section 2). The test packages (`tests/elements/<package>/`: `Test` with the test classes `Action_Test*`, and `TestTwin`, whose classes have the names of two classes of `Test`, E0045) are in separate blocks, `tests/integration/helpers/entry/generated/TestElements_<role>.ahk`, that only the test entries include. The test roles (`EchoRole`, `CrasherRole`, `HangerRole`, `SlowShutdownRole`, `RegisterFailure`) are in `tests/integration/helpers/`. The test entry `tests/integration/helpers/AutoHotFlowTest.ahk` is the supervisor and, for a direct start in a test (`--role=engine ...`), every role in one process with all classes; its children start from `tests/integration/helpers/entry/<role>.ahk` (the product entry plus the test blocks) and, with `--test-roles`, from `entry/test/<role>.ahk` (one test role each, registered only with `--test-roles`). With `--test-roles` at the product entry nothing happens (the roles are not compiled in, their name is unknown). `src/` includes nothing from `tests/` (guard rule `include-tests`, no exception any more). **Manager:** the stub manager uses no element class (grep of `src/manager/`: no `ElementRegistry`, no class metadata), so its entry includes none. If the real manager needs the metadata, it loads all classes (accepted, E0041). **Memory:** MS-0033.
- Each file under `src/` has at most one class (WI-0029): `core/Errors.ahk` now includes only `ErrCode.ahk`, `AhfError.ahk`, `ProtocolError.ahk`, `AhfTimeoutError.ahk`, `ElementError.ahk`, `JsonError.ahk`; `PlaceholderRole` has `core/PlaceholderRole.ahk`; `engine/core/Loops.ahk` is called `LoopStack.ahk`.
- A role is registered by its own entry script, not in `core/RoleRegistry.ahk`, so that `core/` does not include any role folders.
- `core/Lang.ahk` and `core/LangTable.ahk` (WI-0042, E0028): `Lang(key, args*)` for every role; the texts are the v1 language files in `assets/language/basic/` (copied unchanged from `v1/language/basic/`) and those of the element packages (`elements/Default/language/`, copied unchanged from the v1 package Default, WI-0047), read once at the first call.
- `engine/vars/` (WI-0040): the variable model of the engine (scopes, built-in variables, `%var%` substitution, the resolver of the evaluator), doc/EXPRESSION-LANGUAGE.md section 18. It replaces `elements/base/VarStore.ahk` of Phase 2; `ExecContext` gets the access object from the engine. `VarLoader` and `VarWriter` (WI-0041) load the global and static variables through `storage` at the start and write the changes back, PROTOCOL 4.6.

Rule: a folder under `src/` is a process role or library module. `core/` may not include anything from role folders. Role folders include only `core/`, `expr/` (library, includes only `core/`), `ui_common/` (UI roles only) and `elements/`, never each other.

---

## 9. Performance budgets (targets, measured in Phase 2)

The budgets are requirements in `doc/REQUIREMENTS.md` (REQ-PRF-010 to REQ-PRF-060), which also keep their status and evidence. This section defines them in detail. A change of a budget changes both documents in the same commit.

- Message latency locally (engine ↔ client via hub, REQ-PRF-010): median below 5 ms, 99 % below 50 ms.
- Engine state change until editor redraw (REQ-PRF-060): below 50 ms with a non-blocked editor.
- Idle CPU of the overall system without running flows (REQ-PRF-020): below 1 %.
- Memory (E0040, 2026-10-15, REQ-PRF-030): **private bytes** (`psutil` `private`, not the working set, which counts shared pages in every process) of the background processes below 100 MB in total: supervisor, storage, engine, triggerhost, manager and the workers. This is the **normal state**: small flows running now and then, up to about 3 workers active (idle workers stay 60 s). Editors are not counted. Peaks with more active workers may exceed it; performance comes first there. Users who need less memory limit the workers: the engine never has more than N workers (`--workers=<n>`, default 4, 0 to 8, section 6.4; the supervisor passes the option on to the engine), and the supervisor additionally refuses more than `workerLimit` living workers (`Children.WORKER_LIMIT`, default 16, a guard against a faulty engine). A settings entry for the user does not exist yet; the option is on the command line of `AutoHotFlow.ahk` (`--worker-limit` exists only with `--test-roles`). **Measured (MS-0033, WI-0047-PREP, 150 synthetic classes with a guessed mode mix):** 49.0 MB with one worker, 67.7 MB with three, 77.0 MB with four (the default maximum N); before the role entries (MS-0032) 129.0 and 171.9 MB for one and three. Each additional worker costs about 9.4 MB, so the 16 workers of `workerLimit` would be about 189 MB (information, not a failure; reachable only with `--workers=8` at most, because N is limited to 8).

**Decision E0005 (2026-10-11):** The target for idle CPU applies to the **overall system**. Measured 0.23 % (8 CPUs, WI-0016), fulfilled. The reading "sum in percent of one core" (1.8 %) is therefore no longer the yardstick. An optimization is not a requirement and is listed as an observation point in `doc/OPEN-ITEMS.md`.

---

## 10. Risks and open points

| # | Risk / open point | Countermeasure |
|---|---|---|
| R0001 | Overlapped named pipes in AHK v2 are error-prone (OVERLAPPED structure, handle lifetime). | In Phase 2 as a tested library `core/ipc` with a Python counterpart, fault-injection tests. Spike exists. |
| R0002 | Drawing in the editor process could stutter with very large flows. | `Renderer` interface, measurement in Phase 3, separation criterion in 2.1. |
| R0003 | Including all element classes in every role costs parse time and memory (v1: 29,000 lines). With one entry point (D0012) every process parses all elements; a split per role needs separate entry scripts. | **Measured (WI-0046, `doc/MEASUREMENTS.md` MS-0027 to MS-0029): decision question for the project owner.** With 150 synthetic elements of 160 lines (the size of v1) the parse time grows by 48 ms and the start of a worker by 4 ms (both below the thresholds of 150 ms), but every process needs 11.5 MB more private memory (about 75 KB per class; threshold 10 MB, so exceeded). With about 10 processes this is about 115 MB on top of the budget of 100 MB (section 9), which the chain without elements already touches (private about 10 MB per process). **Decided (E0040, E0041, 2026-10-15):** option A without B; the budget scope is E0040. Engine and editor parse all classes (metadata for the conversion, the editor is not budgeted); the manager loads the classes if it needs them (accepted, optimization after the port). **Implemented in WI-0047-PREP (D0012, section 8): result MS-0033, one worker 49.0 MB instead of 129.0 MB, three workers 67.7 MB instead of 171.9 MB (150 synthetic classes).** Options as they were considered (A to D): (A) separate entry scripts per role: supervisor, storage and debug without elements, the worker only with worker elements, the engine with the runtime of the inline elements, the editor and the manager with the metadata; changes D0012 (several entries) and R0007 (one artifact per entry or a launcher). (B) Metadata (`Name`, `Parameters`, `GenerateName`, `CheckSettings`) and runtime code (`Run`) in separate files: only helps together with (A), because AHK includes are static and there is no lazy loading. (C) Only a smaller entry for the roles without elements (supervisor, storage, debug, a first step of A). (D) Accept the cost and redefine the memory budget as private bytes, or raise it. |
| R0004 | Elements with a need for callbacks to the engine (`GetVariable` in the worker) need request/response without `await`. | **Closed (WI-0050).** The variable requests `cmd.engine.var.*` (PROTOCOL 4.5): every variable function of a worker element asks the engine and waits blocking for the answer (own process); the engine answers at once from its variable model and never waits. Round trip about 1 ms (MEASUREMENTS MS-0031). `ctx.Request(type, payload, callback, timeoutMs)` for other requests (ELEMENT-API-V2 3, 3.2). |
| R0005 | Execution policies (`default`, `parallel`, `skip`, `wait`, `stop`): exact semantics must be taken over from `newInstance` and `executionTask`. | Characterization tests against v1 before the port (Phase 3). |
| R0006 | Behavioral deviation: engine crash loses running instances. | Documented in [MIGRATION.md](MIGRATION.md). v1 had the same effect when the whole process crashed. |
| R0007 | Installer/compilation (Ahk2Exe v2, one artifact with role parameter). | Later phase. With E0041 the build has several entry scripts (one per role): the installer or a launcher must bundle them (WI-0047-PREP).
