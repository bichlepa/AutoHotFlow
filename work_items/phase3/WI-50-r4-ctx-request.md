# WI-50 R4: `ctx.Request` and variable access in the worker

Size: M · Depends on: WI-42 · Blocks: WI-55, WI-56

## Goal

A worker element has the same variable functions as an inline element (ARCHITECTURE R4). It asks the engine with request/response and a timeout; the worker may wait blocking, the engine never.

## Read first

`doc/ARCHITECTURE.md` 2.3, 4.2 (pause: clients read and change variables), 6.4 and 10 (R4), `doc/PROTOCOL.md` 4.5 (`cmd.engine.var.get` is documented but not implemented), `doc/ELEMENT-API-V2.md` 3 and 3.1 (rows marked "Worker: R4 (S2)"), `doc/MIGRATION.md` M-45, `src/worker/WorkerContext.ahk`, `src/engine/WorkerBridge.ahk`, `src/engine/vars/`.

## Starting point (verified by reading, 2026-10-14)

A worker gets copies of the visible loop, thread and instance variables with the job (M-45). Missing in the worker: global, static, hidden and built-in variables, `SetVar`, `DeleteVar`, `GetVarLocation`, `ListVars`, `ReplaceVariables`, `EvaluateExpression`, `EvaluateScript`, `ExportInstanceVars`, `ImportInstanceVars`.

## Tasks

1. **Protocol first (own commit):** generalise `cmd.engine.var.get` into a small set of requests from the worker to the engine (read, write, delete, location, list, substitute, evaluate), all with `execId` (or `instanceId`, task 5), a timeout, and the error `gone` when the execution has ended or was stopped.
2. **Engine side:** the requests are answered at once from the variable model of the instance of `execId` (no blocking call, no file I/O); `global`/`static` writes go through the existing write-behind (WI-41).
3. **Worker side:** the `ctx` functions of the list above block until the answer comes or the timeout ends (then `ElementError` "engine did not answer"). `ctx.Request(type, payload, callback, timeoutMs)` as in ELEMENT-API 3 for other requests.
4. **Resolve M-45 (provisional since WI-40):** decide whether a worker still gets copies of the visible variables with the job, and whether `GetVar` reads that copy or always asks the engine; and whether a `SetVar` in the worker also changes the copy (the element should read what it has written). Weigh consistency (a variable that another thread changes meanwhile) against the number of round trips. Update M-45 to a final entry.
5. **Usable by clients later:** cut the requests so that a client can use them too, not only a worker: address an instance (`instanceId`) and not only an execution (`execId`). ARCHITECTURE 4.2 needs this for the pause of the debugger ("clients can read and change all variables of an instance"), and the flow runner of WI-49 needs to read the variables of an instance. Build only what the worker and the test runner need; the debugger is not part of phase 3 (E19).
6. **Stop during a request:** the engine answers `gone`; the worker ends the element. Test with a hanging element that asks after its stop.
7. **Measure** the round trip of one request (worker to engine and back) and record it in `doc/MEASUREMENTS.md`.

## Acceptance criteria

- A test element in `tests/` calls every variable function in the worker; the result equals the same element inline (same flow, both modes).
- Engine restart, worker crash and stop during a request: no hanging process, no error in the engine.

## Docs

`doc/PROTOCOL.md` 4.5, `doc/ELEMENT-API-V2.md` 3 (remove "Worker: R4 (S2)"), 8, `doc/ARCHITECTURE.md` 10 (R4 closed), `doc/MIGRATION.md` (M-45 final, and anything else that differs from v1), `doc/MEASUREMENTS.md`.

## Not part of this

`ctx.RunScript` (S8, E39).
