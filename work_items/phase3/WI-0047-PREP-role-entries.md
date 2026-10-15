# WI-0047-PREP Role entry scripts and memory per role

Size: M · Depends on: WI-0046, WI-0042 · Blocks: WI-0047 and everything after it · Decisions: E0040, E0041 (2026-10-15)

## Goal

Every process parses only the element classes its role needs (E0041), and the memory of the background processes is measured per role (E0040). This comes before WI-0047, because WI-0047 builds the package layout and its include blocks on top of the role entries.

## Read first

E0040 and E0041 in `doc/DECISIONS.md` and `work_items/phase3/README.md`; `doc/ARCHITECTURE.md` 2, 8, 9, D0012, 10 (R0003, R0007); `doc/ELEMENT-API-V2.md` 2; `doc/MEASUREMENTS.md` MS-0027 to MS-0030 and the method "R0003 and load phase"; `src/AhfBoot.ahk`, `src/AutoHotFlow.ahk`, `src/core/RoleRegistry.ahk`, `src/supervisor/Children.ahk` (how the roles are started, `workerLimit`), `tools/measure_r3.py`, `tests/integration/helpers/AutoHotFlowTest.ahk`, `tools/arch_check.py`.

## Tasks

1. **Baseline first.** Measure the private bytes of each role with the current entry (every role parses all classes): supervisor, storage, debug, engine, manager, one worker, each with 0 and 150 synthetic classes (`tools/measure_r3.py`, a memory mode per role). Record as MS-0032 in `doc/MEASUREMENTS.md`. Without this baseline there is no "before".
2. **Selection by `Mode`.** The generator (`tools/gen_element_includes.py`, see WI-0047) reads the literal `static Mode := "<inline|worker|trigger>"` of each class file as text. A missing or non-literal `Mode` fails the generation with the file name. Selection per role:

   | Role | Classes included |
   |---|---|
   | supervisor, storage, debug | none |
   | manager | none expected; if it needs class metadata, it loads all classes (accepted, E0041) |
   | engine | all (`Parameters("")` for the conversion, WI-0039; `Run`/`Stop` for `inline`) |
   | triggerhost | `trigger` |
   | worker | `worker` |
   | editor (not budgeted) | all |

   The test classes (`Action_Test*`) are added only by the test entry, as today.
3. **Entry scripts.** One entry script per role. The file names and the launch are decided here and written into D0012 and `doc/ARCHITECTURE.md` 8. Proposal: `src/entry/<role>.ahk` for each role; each starts with `#Requires AutoHotkey v2.0`, the shared core and its own role blocks, then `AhfMain()` for the role. `src/AutoHotFlow.ahk` stays the file the user starts. The supervisor starts the other roles with their own entry script (`Children`), not with `--role` on the same file. Check first how `Children` builds the command line today.
4. **Shared core.** `src/AhfBoot.ahk` is split into the part every role needs (`RoleRegistry`, the `Ahf*` helpers, the protocol code) and the role includes. A role does not include code of another role that it never runs.
5. **Verify the selection.** A fast-tier test (no process) checks, per role, which classes its generated block registers. A test starts each role entry, reads `cmd.diag.snapshot` (WI-0028) and checks `ready`. Worker elements never run in the engine process; this is already the case (`src/engine/Executor.ahk`, the routing by `Mode`), and a test covers it.
6. **Test entry.** The test entry keeps the test roles (`--test-roles`) and keeps working, including the test elements.
7. **Measure after.** The measurement of task 1 again, plus the sums for one and three workers at 0 and 150 synthetic classes. Record as MS-0033. Check against E0040: the background sum below 100 MB private bytes in the normal state (150 classes, 1 to 3 workers active). The sum with 16 workers is recorded too, as information, not as a failure. The estimate before measuring is about 75 to 80 MB for one worker (not measured).
8. **`workerLimit`.** The default stays 16 (owner decision, 2026-10-15). The budget is the normal state (E0040), so this package measures the sums for 1 to 3 active workers and documents what 16 would cost at peak (about 14 MB per worker, estimate). Users with a need for less memory limit `workerLimit`; the docs say how.
9. **Docs.** `doc/ARCHITECTURE.md` 2 and 8 (entries, layout), D0012 and R0007 (the decision is written there already), `doc/ELEMENT-API-V2.md` 2 (registration per role), `doc/MEASUREMENTS.md` (MS-0032, MS-0033 and the method), `doc/CONVENTIONS.md` (a role entry includes only its generated blocks; `Mode` is a literal), `doc/PROTOCOL.md` only if the launch changes (arguments, exit codes).
10. **VS Code tasks.** The `Start:` tasks keep starting `src/AutoHotFlow.ahk`. A new memory tool or a changed R0003 tool is a task in `.vscode/tasks.json` in the same commit.

## Acceptance criteria

- Each role entry starts and reports `ready`. A role registers only the classes of its row in the table (test).
- The baseline (MS-0032) and the result (MS-0033) are in `doc/MEASUREMENTS.md`, with the sums for one and three workers at 150 classes and the method.
- The generator fails on a class without a literal `Mode` (test).
- The manager's needs are documented (result of the grep in the report). If it loads the classes, that is accepted (E0041); optimization is a later item.
- Fast tier green, `tools/arch_check.py` at 0 violations. The slow and foundation tiers run at the end of the package, because it changes the start of the processes.
- `tests/stress/test_big_flows.py` runs at the end (rule of the README, S0002): time to `evt.engine.ready` and the largest snapshot answer are in the result and within the budget.

## Docs

`doc/ARCHITECTURE.md` 2, 8, 9, 10; `doc/ELEMENT-API-V2.md` 2; `doc/MEASUREMENTS.md`; `doc/CONVENTIONS.md`; `doc/HOW-TO.md` for AHK v2 difficulties; `.vscode/tasks.json` where a call changes.

## Not part of this

Splitting metadata and runtime code (R0003 option B, not chosen for now). Lowering the manager's memory by not loading the classes (after the port, if it matters). The memory of the editors (own budget, not defined). The core-set elements (WI-0052 to WI-0056).
