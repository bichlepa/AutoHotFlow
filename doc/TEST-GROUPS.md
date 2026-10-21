# Test groups: which tests a change needs

A full test run takes minutes, and most of it is irrelevant to most changes: a bug fix in `GuiLayout.ahk` does not need the IPC, supervisor or manager tests, a new element does not need the engine tests. This document describes how the repository decides which tests a change needs, and what to do when you write new source code or new tests.

The decision is made by **judgement written down in one table**, not by a tool that follows `#Include` lines: nearly every file includes `Errors.ahk` and the element base, so the include graph says "everything" for almost any change (tried and dropped, 2026-10-18). The table says what each test *verifies*; the include graph is not used.

**Verified** means measured with `tools/select_tests.py` on 2026-10-18 (history medians, see "Numbers"); **by rule** means decided in this document and not measured.

## 1. The principle

Every source file belongs to one **area** (`SOURCE_AREAS`), every test belongs to one or more **test groups** (`TEST_GROUPS`). A change selects three levels of tests:

1. **Own tests, in full.** The test group of the area. For one element file only the tests of that element (`COVERS`), not the flow tests of all elements.
2. **Smoke tests of the users.** A shared module has users (the manager, a flow run, the trigger host, a dialog element, the worker). For each user one or a few fast tests (`SMOKE_FOR`) show that the features the user needs from the shared module still work. They run whenever the shared module changes.
3. **Everything.** Only when the change can break anything: the `base-hub` files (`Errors.ahk`, `Log.ahk`, `Json.ahk`, `AhfBoot.ahk`), the shared test infrastructure (`tests/conftest.py`, `tests/support/`, `Assert.ahk`, the test entry `AutoHotFlowTest.ahk`), `tools/ahkrun.py`, `pytest.ini`, and the pinned test dependencies. Each of them is an explicit rule with the word everything in its comment, and the end of every larger block of work.

A changed path that **no rule knows is an error**, not a full run: `select_tests.py` exits 2, `verify.py --auto` gives the verdict `error`, and `pytest --changed-from` is a usage error. The message names the file and says what to add (section 6). The guard test `tests/test_groups.py` checks that every tracked file of the repository is known, so the gap shows on the commit that adds the file.

**A deleted file is not an unknown path.** A path that the change deletes (also the old path of a rename) has no rule to find once it is gone. Its own rule still applies when it has one (the groups of its area); a deleted path without a rule selects **everything**, because a deletion can break any test. The deletions come from `groups.removed_paths` (`git diff --diff-filter=D`) and are passed to `groups.select(paths, removed)` by `verify.py --auto`, `select_tests.py --from` and `pytest --changed-from`. Found with WI-0088, which removed `src/core/PlaceholderRole.ahk`.

Two cheap groups always run with any change that tests may read: `docs` and `architecture` (together about 2 s). A test that is **not** in the table always runs: a forgotten entry costs time, never a missed test.

Not selected by the groups, whatever the change: `gui`, `stress`, `soak` and `idle` tests (they depend on the machine, not on the change; unchanged rules in `doc/TEST-STRATEGY.md` section 6) and the group `perf` (scaling measurements, only in full runs).

## 2. Commands

| Task | Command |
|---|---|
| What does my change need? (shows areas, groups, smoke tests; `--time` adds the count and the summed time) | `python tools/select_tests.py --from v2-port --time` |
| What would a change of this file need? | `python tools/select_tests.py src/core/GuiLayout.ahk` |
| Run what my working tree needs | `python -m pytest tests -q --changed-from v2-port` |
| Run the tests of named groups | `python -m pytest tests -q --groups ui,docs` |
| Verify a commit with the selection (the choice since the last green state; the normal case before a cherry-pick) | `python tools/verify.py --auto` |
| Verify everything (end of a block) | `python tools/verify.py` |
| Table of typical changes with the summed time | `python tools/select_tests.py --simulate` |

`--changed-from REF` and `--groups` run the slow and foundation tests of the selected groups as well, but never gui, stress, soak or idle tests. A plain `python -m pytest tests -q` is unchanged (the fast tier). `verify.py --auto` runs the one tier `select` (`pytest --changed-from <base>` on the frozen commit); it runs all three tiers when the change selects everything or when there is no last green state.

**Before a cherry-pick** the selection is enough. **After a larger block** run `python tools/verify.py` (all tiers). If the full run shows a red test that the selection of that block's changes would not have run, the table is wrong: fix it (section 6) in the same commit as the fix of the test.

## 3. Areas of the source code (`SOURCE_AREAS`)

The first matching pattern wins; `*` also matches `/`. Test groups that run in full when the area changes: the group of the same name, except where the third column says otherwise.

| Area | Files | Own test groups (besides `docs`, `architecture`) |
|---|---|---|
| `base-hub` | `AhfBoot`, `AutoHotFlow`, `Errors`, `ErrCode`, error classes, `Json`, `Log` | **everything** |
| `settings` | `SettingsModel`, `EngineSettings`, `SettingsFile` (WI-0077) | `settings` (the model units, the settings in a session, the import of the settings of v1) |
| `util` | `Args`, `Ids`, `Time`, `AhfVersion` | `util` |
| `lang` | `Lang`, `LangTable` | `lang` |
| `transport` | `core/ipc/`, `PipeNames`, `Role`, `RoleRegistry` | `transport` |
| `supervisor` | `supervisor/` (hub, children, launcher, commands) | `supervisor` |
| `recovery` | `Heartbeat`, `Shutdown`, `Stall` | `recovery` (crash, hang, shutdown, orphans, stall) |
| `diagnosis` | `DiagLog`, `DiagReport`, `ReportText`, `Snapshot`, `ProcInfo`, `Debug`, `debugview/` | `diagnosis` |
| `engine` | `engine/` (executor, flows, scheduler, runaway guard, ...), `entry/engine`, `core/FlowPatch.ahk` (WI-0093) | `engine` (includes the loop logic) |
| `variables` | `engine/vars/`, `VarRequests`, `ImportV1Vars` | `variables` |
| `workers` | `worker/`, `WorkerBridge`, `entry/worker` | `workers` |
| `expr` | `expr/`, `FlowExprConvert` | `expr` |
| `triggers` | `triggerhost/`, `TriggerArms` | `triggers` |
| `storage` | `storage/` | `storage` |
| `elements-base` | `AhfElement`, `ElementRegistry`, `ElementRunner`, `ExecContext`, `ParamEvaluator` | `element-units` |
| `ui` | `ui_common/`, `GuiLayout`, `DialogWindow`, `Dialogs`, `entry/editor` | `ui` |
| `element` | one element file or element library (`Actions/`, `Conditions/`, `Loops/`, `Triggers/`, `lib/`) | its `COVERS` tests |
| `elements-pkg` | `_includes_*`, `package.json`, `language/`, icons | `element-units`, `packages` |
| `elements-gen` | `entry/generated/` (written by `tools/gen_element_includes.py`) | `element-units` |
| `manager` | `manager/`, `NoticeThrottle` | `manager` |
| `tray` | `tray/` | `tray` |
| `editor-form` | `editor/form/` (the settings form model of an element, WI-0105) | `editor-form` |
| `editor-geometry` | `editor/` (the geometry, the view, the scene and the hit test, WI-0084) | `editor-geometry` |

Outside `src/` the rules are `OTHER_RULES` in `tests/support/groups.py` (first match wins): `doc/` runs `docs` and `architecture` only (`doc/PROTOCOL.md` also `transport`); `tools/<tool>.py` runs the group `tools` (exceptions listed first); a helper or a data file of `tests/` names the groups of the tests that read it, or `None` (everything) for shared infrastructure, or `[]` when no test reads it (`tests/stress/stresskit.py`: only the stress tests read it, and the selection never runs them); benchmarks and probes that no test calls name the groups of the code they exercise; `v1/` is the reference code and names no group except the golden data (`v1/AutoHotKey/`, `v1/Source_Elements/`); a changed test file selects itself; `work_items/`, `.claude/` and `NEEDS-ATTENTION.md` select nothing. A file of `src/` that no area pattern matches is an error as well: a new folder needs an area in `SOURCE_AREAS`.

## 4. Test groups (`TEST_GROUPS`)

A test file may verify several things; its groups are listed in `tests/support/group_table.py`, paths relative to `tests/` (AHK units as `ahk/<name>.test.ahk`).

| Group | Verifies |
|---|---|
| `settings` | the global settings: checks, file, live effect, import of the settings of v1 |
| `base`, `util`, `lang` | the units of the core helpers, the log, JSON and the texts |
| `transport` | pipes, frames, peers, the role base, pipe breaks and timeouts |
| `supervisor` | start, readiness, routing, role entries, second start |
| `recovery` | crash, hang, shutdown, orphans, stall |
| `diagnosis` | snapshot, report, debug dump and role |
| `engine` | flow runs, flow commands, scheduler, categories, runaway guard, the v1 acceptance, the loop logic |
| `variables` | variable model, requests, files, persistence |
| `workers` | the worker pool and its life cycle |
| `expr` | expression units, oracle, golden data, v1 conversion, migration classes |
| `triggers` | trigger host, arming, state, time triggers, hotkey arming |
| `storage` | storage role, write queue, log files, reports, flow lifecycle files |
| `ui` | dialogs, windows, `GuiLayout`, the UI texts |
| `manager`, `tray` | the manager headless (flows, import, log, notices), the tray |
| `editor-form` | the settings form of an element without a window: fields, values, checks, CheckSettings (headless) |
| `editor-geometry` | the flow geometry, the view math (zoom, move, DPI), the scene and the hit test (headless) |
| `element-units` | the `ahk/element_*.test.ahk` units and the generated include lists |
| `elements-e2e` | flow-builder tests of single elements (only through `COVERS` or in a full run) |
| `packages` | loading of element packages |
| `perf` | scaling measurements (long loops); full runs only |
| `docs` | index, requirements, open-item IDs |
| `architecture` | the architecture check, no v1 dependency, line endings, this table |
| `tools` | the test tooling and the other tools, the runner checks |
| `test-support` | tests of `tests/support/` |

`NODE_GROUPS` gives single test functions (`file::function`) a different group than their file: the generic loop logic in `test_core_c_loops.py` runs with the engine, the two scaling tests there are `perf`.

## 5. Elements, smoke tests

**One element file** (`src/elements/Default/<kind>/Element.ahk` or `lib/`) runs the tests listed for it in `COVERS` (a test file, a unit, or single test functions as `file::function`), plus `ahk/element_smoke.test.ahk` (every registered element), plus the smoke tests of area `element` (one flow run with elements). A **trigger** element also runs the smoke test of `element-trigger` (arming and firing of a trigger). An element library (`ListOps`, `LoopOps`) runs the tests of all elements that use it. An element with no covering test (`[]`) runs the element units only. The guard test requires an entry for every element file.

Example (verified, summed time of the selected tests): `Loop_SimpleLoop.ahk`: 12 s (its own tests and the smoke tests; not the generic loop logic, which runs with the engine, and not the 123 s of scaling tests, which are `perf`); `Trigger_Periodic_Timer.ahk`: 15 s.

**Smoke tests (`SMOKE_FOR`)** map a test (a file, a unit or `file::function`) to the areas it stands in for. Choose them like this:

- one or a few per *user* of a shared module, each small enough that its cost is in seconds;
- it must go through the shared module the way the user does (a manager test that imports flows is the smoke test of `storage` for the manager);
- write down what it does not catch (in the pull request or here): the own tests of the area catch the rest.

## 6. What to do when you write code or tests

**New source file** (`python -m pytest tests/test_groups.py -q` fails with the missing entry):

1. A file in an existing folder is usually covered by a pattern. If not, add a pattern to `SOURCE_AREAS`.
2. A new element file needs a `COVERS` entry: its tests (its own test file, or the functions of a shared file as `file::function`); `[]` only if it really has none yet. Prefer a test function that names the element, so the entry stays short and exact.
3. A new area (a new module family, a new role) needs: a pattern, a test group of the same name (or an entry in `OWN_TEST_GROUPS`), the test files in that group, and, when other modules use it, smoke tests for its users.
4. A new **shared** module (used by several areas): add one smoke test per user in `SMOKE_FOR`.
5. A new file that is **not** code (a helper, data, a library, a document): a rule in `OTHER_RULES` (`tests/support/groups.py`). Name the groups of the tests that read it. Use `None` only for shared infrastructure that any test may depend on, with a comment that says so; `[]` only when no test reads it.

**A path that no rule knows** (the selection says `... is not classified by any test rule`): the fix is one of the rules above, not a full run. Do not add a catch-all pattern to get past the error; `tests/test_groups.py` (`test_every_tracked_file_is_classified_by_a_rule`) fails for every tracked file that stays unknown.

**New test file or test function:**

1. Add the file to `TEST_GROUPS` with the groups of what it verifies (one or more). The guard test fails until you do; without an entry the test would run for every change.
2. A test function that belongs elsewhere than its file: `NODE_GROUPS`. A scaling or throughput measurement that needs minutes: group `perf`.
3. A test that stands in for a user of a shared module: `SMOKE_FOR` (section 5).
4. Test of the tooling: group `tools`; of `tests/support/`: group `test-support`.

**A red test in a full run that the selection had skipped:** the table was wrong. Add the group, the smoke test or the `COVERS` entry that would have selected it, and say so in the commit message. Do not widen a group out of habit: groups are small on purpose.

**Changes to the table itself** (`tests/support/group_table.py`, `tests/support/groups.py`) run the guard test only. The logic of the selection is in `tests/support/groups.py`; `tests/conftest.py` (`--changed-from`, `--groups`, `--changed-paths`), `tools/verify.py` (`--auto`) and `tools/select_tests.py` use it.

## 7. Numbers

`python tools/select_tests.py --simulate`, 2026-10-18, commit state of the branch that introduced the groups. Test times are medians of the newest 15 passed runs of the history; the sum is the work of all tests added up, not the wall clock time (the run takes a fraction of it with parallel workers). Full set: 2107 tests, 1913 s.

| Change | Tests | Sum | Share |
|---|---:|---:|---:|
| `GuiLayout.ahk`, `UiWindow.ahk` | 159 | 56 s | 2.9 % |
| a new element (no `COVERS` yet) | 325 | 15 s | 0.8 % |
| `Action_Sleep.ahk` | 116 | 5 s | 0.3 % |
| `Action_Message_Box.ahk` | 127 | 48 s | 2.5 % |
| `Action_Add_To_List.ahk` | 141 | 28 s | 1.5 % |
| `Loop_SimpleLoop.ahk` | 118 | 12 s | 0.6 % |
| `Trigger_Periodic_Timer.ahk` | 110 | 15 s | 0.8 % |
| `ListOps.ahk` (library of all list elements) | 154 | 147 s | 7.7 % |
| `ElementRunner.ahk` | 327 | 15 s | 0.8 % |
| `ExprEvaluator.ahk` | 406 | 107 s | 5.6 % |
| `Frame.ahk` | 252 | 120 s | 6.3 % |
| `Hub.ahk` | 212 | 154 s | 8.1 % |
| `Storage.ahk` | 245 | 213 s | 11.2 % |
| `Stall.ahk` | 141 | 210 s | 11.0 % |
| `Executor.ahk` | 442 | 301 s | 15.7 % |
| `Errors.ahk`, `tools/ahkrun.py` | 2101 | 1890 s | 98.8 % |
| `tools/verify.py` | 316 | 102 s | 5.3 % |
| `doc/REQUIREMENTS.md` | 97 | 2 s | 0.1 % |

The "Tests" column includes the AHK case items of the selected units (a unit file is one run with many cases). The biggest remaining costs are the own test groups of the engine, storage, recovery and the trigger host. They can be narrowed the same way as the loops: split the area, assign `NODE_GROUPS`, or add smoke tests, once the practice shows which changes hurt.

## 8. Where things are

| What | Where |
|---|---|
| The table (areas, test groups, element coverage, smoke tests) | `tests/support/group_table.py` |
| The selection rules, the rules of the paths outside `src/` (`OTHER_RULES`), the error of an unknown path | `tests/support/groups.py`, `tests/conftest.py` (`--changed-from` support) |
| Verification with the selection | `tools/verify.py --auto` |
| Explanation and simulation | `tools/select_tests.py` |
| Guard (the table is complete and true; examples of what is selected) | `tests/test_groups.py` |
