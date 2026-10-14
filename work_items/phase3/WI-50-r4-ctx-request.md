# WI-50 R4: `ctx.Request` and variable access in the worker

Size: M · Depends on: WI-42 · Blocks: WI-55, WI-56

## Goal

A worker element has the same variable functions as an inline element (ARCHITECTURE R4). It asks the engine with request/response and a timeout; the worker may wait blocking, the engine never.

## Read first

`doc/ARCHITECTURE.md` 2.3, 6.4 and 10 (R4), `doc/PROTOCOL.md` 4.5 (`cmd.engine.var.get` is documented but not implemented), `doc/ELEMENT-API-V2.md` 3 and 3.1 (rows marked "Worker: R4 (S2)"), `doc/MIGRATION.md` M-45, `src/worker/WorkerContext.ahk`, `src/engine/WorkerBridge.ahk`, `src/engine/vars/`.

## Starting point (verified by reading, 2026-10-14)

A worker gets copies of the visible loop, thread and instance variables with the job (M-45). Missing in the worker: global, static, hidden and built-in variables, `SetVar`, `DeleteVar`, `GetVarLocation`, `ListVars`, `ReplaceVariables`, `EvaluateExpression`, `EvaluateScript`, `ExportInstanceVars`, `ImportInstanceVars`.

## Tasks

1. **Protocol first (own commit):** generalise `cmd.engine.var.get` into a small set of requests from the worker to the engine (read, write, delete, location, list, substitute, evaluate), all with `execId`, a timeout, and the error `gone` when the execution has ended or was stopped.
2. **Engine side:** the requests are answered at once from the variable model of the instance of `execId` (no blocking call, no file I/O); `global`/`static` writes go through the existing write-behind (WI-41).
3. **Worker side:** the `ctx` functions of the list above block until the answer comes or the timeout ends (then `ElementError` "engine did not answer"). `ctx.Request(type, payload, callback, timeoutMs)` as in ELEMENT-API 3 for other requests.
4. **Writes and copies:** decide and document whether a `SetVar` in the worker also changes the copy that came with the job (the element should read what it has written).
5. **Stop during a request:** the engine answers `gone`; the worker ends the element. Test with a hanging element that asks after its stop.
6. **Measure** the round trip of one request (worker to engine and back) and record it in `doc/MEASUREMENTS.md`.

## Acceptance criteria

- A test element in `tests/` calls every variable function in the worker; the result equals the same element inline (same flow, both modes).
- Engine restart, worker crash and stop during a request: no hanging process, no error in the engine.

## Docs

`doc/PROTOCOL.md` 4.5, `doc/ELEMENT-API-V2.md` 3 (remove "Worker: R4 (S2)"), 8, `doc/ARCHITECTURE.md` 10 (R4 closed), `doc/MIGRATION.md` (if the behaviour differs from v1), `doc/MEASUREMENTS.md`.

## Not part of this

`ctx.RunScript` (S8, E39).
