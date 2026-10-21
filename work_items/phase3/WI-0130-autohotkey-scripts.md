# WI-0130 AutoHotkey script action and trigger (E0039, E0104)

Size: L · Depends on: – · Blocks: WI-0135

## Goal

A flow runs AutoHotkey v2 code of the user, in a process of its own, and exchanges variables with it as v1 did (E0104): the import variables are globals of the script at its start, the export variables are read at its end (action) or at each `x_trigger()` (trigger). A script of a migrated v1 flow does not run until the user has ported it (M-0049). Requirements: REQ-ELM-110.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_AutoHotkey_script` | worker | waits for the end of the script; `result` and `resultmessage` as in v1 |
| `Trigger_AutoHotkey_Script` | trigger | the script runs while the trigger is armed; each `x_trigger()` fires with the export variables (`TriggerVariables` sets them as instance variables, v1 `x_ImportInstanceVars`) |

## Read first

The common part of the element packages (README S0008); `doc/DECISIONS.md` E0039, E0104; `doc/MIGRATION.md` M-0049; `doc/ELEMENT-API-V2.md` 3 (`ctx.RunScript`, `ctx.GetImport`, `ctx.Export`), 3.5; `doc/PROTOCOL.md` 4.4 (arming), 4.5 (`imports`, exports); `src/supervisor/ChildPipe.ahk` (reads the anonymous pipe of a child without blocking); `src/triggerhost/`; AutoHotkey docs: `Scripts.htm` (`*` reads the script from stdin, `/script` of a compiled script, `/ErrorStdOut`), `Run`, `OnExit`; v1: `AutoHotkey_script.ahk` (action and trigger), `x_ExecuteInNewAHKThread`, `x_TriggerInNewAHKThread`.

## Tasks

The common tasks (README S0008) for both classes, and:

1. **Script host library** (`lib/` of the package, shared by worker and trigger host): starts the interpreter of the running AutoHotFlow (`A_AhkPath`; S0009 adds the compiled program with `/script`) with `*` and `/ErrorStdOut=UTF-8`, writes a generated prologue and the user's code to its stdin, and reads JSON lines from its stdout. The prologue: `#Requires AutoHotkey v2.0`, `#NoTrayIcon`, the import variables as globals (texts, numbers; lists and objects through JSON, E0104), the function `x_trigger()` (writes the export variables as one line), an `OnExit` handler that writes the export variables, `result` and `resultmessage`. A load or run error of the user's code comes back on stderr and ends the element with `exception` and that text, with line numbers of the user's code (subtract the prologue).
2. **Action:** the worker waits for the end of the process (blocking is allowed there); the export variables are set with `ctx.SetVar`; stopping the instance ends the process (`Stop`; no process stays behind, also when the worker is killed: a job object or a check at the next start).
3. **Trigger:** the trigger host reads the stdout of the process with a timer, never blocking (rule 3); each line of `x_trigger()` fires (`ctx.Fire` with the variables as data, texts and numbers; objects as JSON text that `TriggerVariables` parses); disarming ends the process; a process that ends by itself is reported (`evt.trigger.error`) and the trigger stays armed without effect. The import variables are evaluated by the engine at the arming (PROTOCOL 4.4 says how they reach the trigger host).
4. **Migrated scripts:** a script of a v1 flow carries its MIGRATION place (M-0049) and ends with `exception` "AutoHotkey v1 code: port it to v2" until the user changes the parameter (the place goes, WI-0093); the help page says how to port (the main differences) and that an AI can help later (REQ-AI-040).
5. **Corpus:** "external script test" (`Flow 1849072261`) on a copy with the scripts ported to v2 by hand (`Sleep 10000`, `MsgBox "..."`; fix list, MIGRATION ID); the stop case checks that the process is gone.
6. **Tests:** imports and exports of every value type, an error in the user's code, stop while running, the trigger firing three times, the disarm ending the process, no process left after the test.

## Acceptance criteria

Those of every element package (README S0008); `ctx.RunScript` is documented in ELEMENT-API-V2 3 as built (or removed from it, if the library makes it unnecessary).

## Not part of this

Running v1 code (E0039); porting the user's v1 scripts automatically (REQ-AI-040, later); the compiled program (S0009).
