# WI-0061 Role `triggerhost`

Size: M · Depends on: – · Blocks: WI-0062

## Goal

The role `triggerhost` replaces its placeholder (D0008, E0006; the phase 2 plan was WI-0014, `git show v2-phase2-final:work_items/phase2/WI-14-triggerhost.md`). It arms and disarms trigger elements on command of the engine, holds their OS handles and reports their events. It never runs flows. An error of one trigger stops neither the others nor the host (REQ-TRG-010). This package builds the host and tests it against the Python hub; the engine side is WI-0062.

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 1 to 6 (3: the role, 6.2: errors, 6.3: shutdown, rank of the trigger host) and 8; `doc/CONVENTIONS.md`; `doc/PROTOCOL.md` 4.4; `doc/ELEMENT-API-V2.md` 2 (trigger contract) and 3 (`ctx.State`, `ctx.Fire`, `ctx.Log`, `ctx.After`) and 5; the README of S0003, "Design fixed while detailing"; `src/entry/triggerhost.ahk`, `src/core/Role.ahk` and a small role as the pattern (`src/storage/Storage.ahk` or the worker); `tests/support/pyhub.py`; HOW-TO entries on timers and `Hotkey`.

## Tasks

1. **Role** `src/triggerhost/TriggerHost.ahk`, registered by `src/entry/triggerhost.ahk` instead of `PlaceholderRole`. Handlers:
   - `cmd.trigger.arm {triggerKey, gen, flowId, elementId, class, params, context}`: looks up the class (`ElementRegistry`), creates a trigger context, calls `cls.Enable(ctx, params)` under `try/catch`; answer `{ok, message?}`, on an exception `ok: false` with the message (an `ElementError` text as it is, anything else with its type). An already armed `triggerKey` is disarmed first (replace, never two timers). An unknown class: `ok: false`, `not_found`.
   - `cmd.trigger.disarm {triggerKey}`: `cls.Disable(ctx)` under `try/catch` (an error is logged `f0`, the trigger is dropped anyway), cancels the timers of the context; answer `{ok}`, also for an unknown key.
   - `cmd.trigger.reset`: disarms every trigger; the engine sends it before it arms (first start, restart of either side). Replaces "the trigger host discards all known ones on `evt.engine.restarted`" in PROTOCOL 4.4.
2. **Trigger context** (`TriggerContext`): `flowId`, `elementId`, `triggerKey`, `context` (the start context of WI-0062, e.g. `ahfStartup`), `State` (an object per armed trigger), `Fire(data := "")` sends `evt.trigger.fired {triggerKey, gen, flowId, elementId, data}` to the engine (data: a `Map` of texts and numbers; anything else is refused with an `f0` log, the event goes out without it), `Log(level, text)`, `After(ms, fn)` (cancelled at disarm). A `Fire` after the disarm sends nothing. A callback of an element (timer, hotkey) runs under `try/catch`; an error goes to `evt.trigger.error {triggerKey, gen, message}` and the log, the trigger stays armed.
3. **Shutdown:** on `sys.shutdown` the host disarms every trigger, then `sys.bye` (ARCHITECTURE 6.3).
4. **Diagnostics:** `DiagInfo` lists the armed triggers (key, class, generation, time armed), no parameter values.
5. **Test triggers** in `tests/elements/Test/Triggers/` (generator, test blocks): `Trigger_TestTimer` (fires every `Interval` ms with a counter in `data`), `Trigger_TestFail` (`Enable` throws), `Trigger_TestDisableThrows`, `Trigger_TestCallbackThrows` (its timer callback throws), `Trigger_TestFireOnEnable` (fires inside `Enable` when `context.ahfStartup`, the pattern of `Trigger_Start_up`).
6. **Tests** `tests/integration/test_triggerhost.py` against the Python hub: arm `Trigger_TestTimer` with 100 ms, about 5 events in 500 ms (`scaled()`), disarm, no more events; a second arm of the same key does not double the events; `Trigger_TestFail` answers `ok: false` and the host keeps working; `Trigger_TestDisableThrows` is dropped; a throwing callback gives `evt.trigger.error` and the trigger keeps firing; `reset` stops all; the shutdown disarms all and ends with `sys.bye`; an unknown class. Fault test: a crash of the host is restarted by the supervisor (the re-arming is WI-0062).
7. **ELEMENT-API 3:** the members of the trigger context; `ctx.Request` stays for workers (the table says "triggers: S0003": change it to "triggers: when a trigger needs it").

## Acceptance criteria

- The tests of task 6 are green, serial and parallel; the fault test in the foundation tier if it touches the supervisor.
- `python tools/arch_check.py` green (no blocking call in the host).
- Memory of the idle host with the product trigger classes recorded (MEASUREMENTS).

## Docs

`doc/PROTOCOL.md` 4.4 (`gen`, `context`, `cmd.trigger.reset`, `evt.trigger.error` with `gen`), `doc/ARCHITECTURE.md` 3 and 8 (`src/triggerhost/`), `doc/ELEMENT-API-V2.md` 3, `doc/TEST-STRATEGY.md` (test triggers), `doc/REQUIREMENTS.md` REQ-TRG-010 (`partial`), then `python tools/doc_index.py`. VS Code task for the new test module (rule 10) if it is not covered by an existing task.

## Not part of this

The engine side (WI-0062), the real triggers (WI-0063, WI-0064), several hosts (ARCHITECTURE 3, "later n").
