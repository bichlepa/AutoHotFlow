# WI-40 Variable model in the engine

Size: L · Depends on: WI-38 · Blocks: WI-41, WI-42

## Goal

The engine manages all variable kinds from v1 with the same rules for location, visibility and naming. The evaluator (WI-38) accesses them through a resolver. `global`/`static` live here as a working copy in memory; loading and writing come in WI-41.

## Read first

README of this phase (S1, findings, E28), `v1/Source_Execution/Variables/Variables.ahk`, `v1/Source_Common/Variables/Global variables.ahk`, `src/elements/base/VarStore.ahk`, `src/engine/Executor.ahk`, `src/engine/core/LoopStack.ahk`, ARCHITECTURE 4 (data ownership) and 5.2 (loop stack).

## Tasks

1. **Scopes:** `loop`, `thread`, `instance` (per instance/thread), `static` (per flow), `global` (for all flows), each with a hidden variant (`hidden`). Owner is the engine (ARCHITECTURE 4).
2. **Location rules as in v1** (`Var_RetrieveDestination`, `Var_GetLocation`): `A_` names are loop, then thread, then built-in; `global_`, `static_`; otherwise instance. Setting `A_` names only with location `thread`/`loop`, other names never there; errors as in v1 logged as `f0` (golden data cases `destination`). This replaces today's search thread → instance in `VarStore.Find` (deviation that Phase 2 had only provisionally).
3. **Paths into objects:** read, set, delete `a.b`, `a[1]` (v1 `parseObjectPath`). Clarify with the golden data: in v1, are the key `1` and `"1"` the same (`liste.1` versus `liste[1]`)? Order of keys when iterating (v1: integers ascending, then text)? Define representation (E28: `Map` with `CaseSense := "Off"`; whether JSON arrays from variable files arrive as `Map` with keys 1..n or as `Array` — decide here and record in `doc/AUSDRUECKE.md`).
4. **Loop variables** connected to the existing `LoopStack`: on entering a loop, visible and hidden loop variables are pushed onto the stack; on leaving, they are restored (v1 `LoopVariable_AddToStack`, note M-19).
5. **Built-in variables:** all 55 + 14 from v1, with a table in `doc/AUSDRUECKE.md`: name, v1 source, v2 source, deviation. Known deviations: `A_IPAddress1` to `4` (v2: `SysGetIPAddresses()`), `A_CaretX`/`A_CaretY` (v2: `CaretGetPos`), `A_PtrSize` (8 instead of 4, E4), `A_ScriptDir` (v1: folder of the program; define in v2), `A_LanguageName` (in v1 always empty, TODO in the v1 code), `A_YWeek` (only the week), `a_NowString`, `a_flowName`/`a_elementName` (from the `FlowTable`), `A_AhfVersion`, `a_workingdir` (E28). Deviations in MIGRATION.
6. **Name check** as in v1 `Var_CheckName` (empty, starts with a digit, forbidden characters), as an explicit rule instead of the v1 trick `asdf%name% := 1`; cross-check with the golden data cases `checkname`.
7. **`%var%` substitution** in texts as in v1 `Var_replaceVariables` (option `ConvertObjectToString`, JSON output for objects), cross-check with the cases `replace`.
8. **Resolver** for the evaluator that uses these rules; variable list (`ListVars` per scope, without hidden and built-in variables).
9. **Worker:** What a worker currently gets as a copy (`Executor._CopyMap(run["vars"])`), adapt to the new model (visible variables of the instance and the thread, no `global`/`static`); the return path of the variables from the worker stays as it is today until S2 (R4).

## Acceptance criteria

- Golden data cases `destination`, `checkname`, `replace` and all cases with variables are equal or have a documented deviation.
- L1 tests per rule; integration test: instance and thread variables separated per instance, `static` separated per flow, `global` shared, loop stack with nested loops.

## Docs

`doc/AUSDRUECKE.md` (variables, built-in variables), `doc/ARCHITECTURE.md` 4, `doc/ELEMENT-API-V2.md` 3 (`ctx.SetVar`/`GetVar`: all scopes), `doc/MIGRATION.md`.

## Not part of this

Files (WI-41), parameter evaluation (WI-42).
