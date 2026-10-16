# WI-0062 Engine: arming, re-arming, fired events

Size: L · Depends on: WI-0060, WI-0061 · Blocks: WI-0063, WI-0064, WI-0065, WI-0066

## Goal

The engine arms the enabled triggers in the trigger host, keeps them armed across restarts of either process, and turns a fired event into an instance with the variables of its trigger. Requirements: REQ-TRG-020, REQ-ROB-040 (triggers), REQ-VAR-080, REQ-MIG-070 (the trigger part), REQ-TRG-010 (engine side).

## Read first

As WI-0060, plus `doc/PROTOCOL.md` 4.4 as WI-0061 left it, `doc/ARCHITECTURE.md` 6.1 (step 4) and 6.2 (engine restart, `--restarted`), `doc/ELEMENT-API-V2.md` 2 (`TriggerVariables`) and 3.1 (parameter evaluation), `src/elements/base/ParamEvaluator.ahk`, `src/engine/Executor.ahk` (`_Start`, `_StartRun`, policies), the README of S0003 ("Design fixed while detailing"), MIGRATION M-0069, `tests/integration/test_corpus.py` (`FIX_LIST`).

## Tasks

1. **Arming:** for every enabled trigger of a loaded flow the engine evaluates the parameters (global, static and built-in variables; no instance) and sends `cmd.trigger.arm` with a new generation number. An evaluation error, an unknown class or a missing package (REQ-MIG-070, E0047) does not arm; the trigger state carries the message. Switching (WI-0060) arms or disarms at once; a flow that leaves the flow table is disarmed.
2. **When:** after `evt.engine.ready`, once the trigger host is `ready` (topic `process`, as the engine waits for storage); first `cmd.trigger.reset`, then the arms, staggered (at most 2 open requests, as the loading). Again after a restart of the trigger host (`evt.process.ready` of `triggerhost`) and after a restart of the engine (the new engine does the same pass). An `arm` without answer (timeout, `peer_gone`) is retried at the next ready of the host, not in a loop.
3. **Start context:** `context.ahfStartup` is true only in the first arming pass after the start of AutoHotFlow (an engine without `--restarted`, and not in a pass after a restart of the trigger host); `context.windowsStartup` is true in that pass when the supervisor was started with `--windows-startup` (new supervisor option, passed to the engine; PROTOCOL / `AhfBoot.ahk` command line). A trigger enabled later gets neither (as v1).
4. **Fired events:** `evt.trigger.fired` with a generation that is not the current one of the trigger, or for a trigger that is not enabled, is dropped (log `a2`). Otherwise the engine starts an instance at this trigger through the existing start path (policies as before) and sets the thread variables `TriggerVariables(params, data)` of the class (with the evaluated parameters of the arming), under `try/catch` (an error: `f0` log, the instance starts without them). `evt.trigger.error` sets the trigger state.
5. **`TriggerVariables` at every start (M-0069 back):** also a start by `cmd.flow.start` and by `ctx.CallFlow` calls it, with the stored parameters evaluated like at an arming and `data` empty. The copy of "variable test" in `tests/data/flows/v2_adapted/` and its two `FIX_LIST` entries go; the test runs the original file. M-0069 is set to done.
6. **State:** `evt.trigger.state` gets `armed` (true after `ok` of the host) and `message` (the error of arming or of the host); the engine snapshot lists per flow the enabled, armed and failed triggers.
7. **Tests:**
   - AHK unit tests: the generation filter, the start context of the passes, `TriggerVariables` with and without data.
   - e2e with the test triggers of WI-0061 through the real chain: enable, events, instances with the trigger variables, disable, no more instances.
   - Fault tests: kill the trigger host, it is restarted and the triggers fire again; kill the engine, the new engine re-arms; `Trigger_TestFireOnEnable` fires after the first start only, not after either restart.
   - A parameter that cannot be evaluated; a trigger of a missing package; a host that is not there (restart limit reached): the engine keeps running, the triggers stay "not armed".

## Acceptance criteria

- The tests of task 7 are green, serial and parallel; the fault tests in the foundation tier; slow tier at the end (timing, supervisor).
- **Load path (F-0073):** `tests/stress/test_big_flows.py` with a timer trigger enabled in each big flow, time to ready and largest snapshot answer in the result, within the budget.
- "variable test" runs green as saved.

## Docs

`doc/PROTOCOL.md` 4.4 (the engine side, `evt.trigger.state`, the start context, the option `--windows-startup`), `doc/ARCHITECTURE.md` 6.1 (step 4) and 6.2 (rows "Engine crashes", new row "Trigger host crashes"), `doc/ELEMENT-API-V2.md` 2 (when `TriggerVariables` runs), `doc/MIGRATION.md` M-0069, `doc/REQUIREMENTS.md` REQ-TRG-020, REQ-ROB-040, REQ-VAR-080, REQ-MIG-070, REQ-EXE-070, REQ-TST-040, then `python tools/doc_index.py`. VS Code task (rule 10): `Start:` with `--windows-startup`.

## Not part of this

The real triggers (WI-0063, WI-0064); re-arming after an edit (S0006); the limits (WI-0066).
