# WI-0066 Guard against runaway flows

Size: M · Depends on: WI-0060, WI-0062 · Blocks: WI-0067

## Goal

A flow that runs away (an endless loop, a trigger flood, a growing queue) is stopped or held back before it disturbs the other flows (E0062, REQ-EXE-170). v1 had no such guard.

## Read first

As WI-0060, plus E0062, REQ-EXE-170, REQ-EXE-050 (policies), `src/engine/Executor.ahk` (start path, policies `skip`/`wait`, `StopFlow`, the counting point of an element execution), `doc/MEASUREMENTS.md` (MS-0017, MS-0023: instance starts per second), `tests/stress/`.

## Tasks

1. **Measure first:** how many element executions per second the engine does with inline elements (a loop over `Action_Do_nothing` and over `Action_New_variable`, and an instance flood with policy `parallel`). Result in `doc/MEASUREMENTS.md`. From it the package **sets the defaults itself** (E0062): a runaway loop is caught within a few seconds, a loop over a list of 10 000 items passes; waiting and parallel instances start at 100 each unless the measurement speaks against it. The values and their reason go into the result; the owner may change them later (they are constants until the global setting of S0004).
2. **Element executions per minute:** the engine counts per flow every element execution, the trigger of a new instance included, in a sliding window of 60 s (60 buckets of one second; no cost per element beyond an increment). Over the limit: all instances of the flow stop (end reason `limit`), all its triggers are disabled, independent ones included, and the state is saved (WI-0060); log `a0`; event `evt.flow.limit {flowId, kind, limit}` for the notice of S0004.
3. **Waiting and parallel instances:** a start that would exceed the limit of waiting instances (policy `wait`) or of running instances is refused: the error code `limit` (new in `ErrCode`, PROTOCOL), `Action_Execute_Flow` ends with `exception` and a message that names the limit, a fired trigger is dropped. A refused start is logged `f1` at most once per 10 s per flow, with the number refused since the last line (a timer of 10 ms must not flood the log).
4. **Settings per flow:** `flowSettings` keys `maxExecutionsPerMinute`, `maxWaitingInstances`, `maxParallelInstances`; missing or `default` means the built-in default (the global setting comes with S0004), 0 means no limit; `cmd.flow.save` keeps them.
5. **Tests:** an endless loop is stopped within the window and its flow is disabled after a restart too; a loop over 10 000 items with the defaults passes; a timer trigger of 10 ms with policy `parallel` and a slow flow hits the parallel limit; with policy `wait` the waiting limit; `Execute_Flow` over a limit ends with `exception`; 0 switches a limit off; the log stays small during a flood. `tests/stress/` unchanged in time (the counting costs nothing measurable).

## Acceptance criteria

The measurement and the chosen defaults with their reason are recorded; the tests of task 5 are green, serial and parallel; slow and stress tiers at the end.

## Docs

`doc/PROTOCOL.md` (end reason `limit`, error code `limit`, `evt.flow.limit`, the `flowSettings` keys), `doc/ARCHITECTURE.md` 4 or 5 (where the counting lives), `doc/MIGRATION.md` (v1 had no limits), `doc/MEASUREMENTS.md`, `doc/REQUIREMENTS.md` REQ-EXE-170, then `python tools/doc_index.py`.

## Not part of this

The notice in the manager and the global defaults (S0004), the fields in the flow settings (S0007), a limit for all flows together.
