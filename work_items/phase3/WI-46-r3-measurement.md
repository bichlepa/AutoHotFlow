# WI-46 R3 measurement: parse time and memory with many elements

Size: S · Depends on: – · Blocks: WI-47

## Goal

Measure what it costs when every process parses all element classes (ARCHITECTURE R3), before real elements depend on the layout. The result decides whether metadata and runtime code must be split.

## Read first

`doc/ARCHITECTURE.md` D12, 9 (budgets) and 10 (R3), `doc/MEASUREMENTS.md`, `src/AhfBoot.ahk`, `doc/ELEMENT-API-V2.md` 2.

## Starting point (verified by reading, 2026-10-14)

There is one entry point for all roles (D12): `src/AhfBoot.ahk` includes every role and every element, so every process (also each worker of the elastic pool) parses all elements. "An include block per role" is only possible with separate entry scripts, which touches D12 and the later compilation (R7). v1 has 162 element files with about 26,000 lines (about 160 lines per element).

## Tasks

1. **Synthetic elements:** a generator writes N element classes of realistic size (about 160 lines, `Parameters` with 10 entries, `GenerateName`, `CheckSettings`, `Run` with some logic, language keys), in a temporary folder, plus an entry that includes them. Not in `src/`.
2. **Measure** for N = 0, 50, 150, 300: start time to `evt.role.ready` (or the equivalent) for engine and worker, private bytes and working set after the start, and the time of a worker start from the pool request to ready. Several runs each, median and spread, on an idle machine (`-m stress` rules).
3. **Assess** against ARCHITECTURE 9 (memory below 100 MB with 5 editors) and the worker start (pool). Proposed threshold for a split: with 150 elements a worker starts more than 150 ms later or a process needs more than 10 MB more than with 0 elements.
4. **If the threshold is exceeded:** describe the options (separate entry scripts per role; metadata and runtime code in separate files; a smaller worker entry) with their effect on D12 and R7, as a decision for the project owner. Do not implement.

## Acceptance criteria

- Values in `doc/MEASUREMENTS.md` (with the command that reproduces them) and in the result.
- R3 in `doc/ARCHITECTURE.md` 10 updated: closed (below the threshold) or a decision question for the project owner.

## Docs

`doc/MEASUREMENTS.md`, `doc/ARCHITECTURE.md` 10.

## Not part of this

The layout itself (WI-47).
