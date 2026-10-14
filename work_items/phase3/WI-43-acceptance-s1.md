# WI-43 Acceptance S1

Size: S · Depends on: WI-36 to WI-42 · Blocks: S2

## Goal

S1 is demonstrably finished, and the documents match the code. Afterwards S2 is detailed.

## Tasks

1. **Golden data:** all checked-in cases are equal or assigned to an "accepted deviation" class; private cases are local (only numbers in the report: count, equal, accepted, open).
2. **e2e:** A v1 flow with the test element is loaded from a v1 folder and converted, runs, and sets a variable of each kind; `global`/`static` are present after restarting the engine and after restarting the session; v2 has not written anything in the v1 data folder.
3. **Acceptance runs:** serial, parallel (rule from `doc/TEST-STRATEGY.md` after WI-34), `-m stress`. Record the new runtime of the full run.
4. **Documents:** `doc/EXPRESSION-LANGUAGE.md` complete (language, differences to AHK v2, differences to v1 and conversion, variables, built-in variables); ARCHITECTURE (4, 6.1, 6.3, 7, 8 `src/expr/`), PROTOCOL, ELEMENT-API, MIGRATION, TEST-STRATEGY, HOW-TO, `AGENTS.md` (status), `work_items/STATUS.md`, `work_items/HANDOVER.md`.
5. **Retrospective:** What did the estimate of the packages miss, what belongs in the scope of S2? Briefly in the result.

## Acceptance criteria

- All checkboxes for S1 in the README are set, runs are green.
- The project owner has seen the discrepancy catalog (WI-39) and the MIGRATION entries.

## Result

State: **not accepted yet.** Tasks 1 to 5 are done, the serial and the parallel run are green, the stress run has one red test (F-268, not repeated, not analysed). WI-43 and its checkbox stay open until the project owner has decided about F-268.

- **Golden data (task 1):** `python tools/golden_v1.py --check`: 2161 cases of 18 groups, the results of v1 are identical to the checked-in ones. `python tools/golden_compare.py`: 1600 agree with v1, 553 have an accepted class of the deviation catalog (189 of them are cases where v1 itself fails or hangs), 8 are syntax that is reported and not converted (the owner decided on 2026-10-14 that it stays unsupported), **0 are open**. The golden tests (`tests/golden`, 44 tests) are green. In each of the groups `assignment` and `script` three cases end in `uncaught`/`timeout` in v1 (6 in total, seen in the `--check` output); they belong to the class "v1 error" and have no entry of their own. The private cases (`tests/golden/private/`) do not exist on this machine, so there are no numbers for them.
- **e2e (task 2):** `tests/fault/test_s1_acceptance.py` (slow tier, 1 test, about 24 s). A v1 flow (`tests/data/flows/s1_acceptance/`, the v1 format with the test elements) lies in a temporary copy of a v1 working directory together with the synthetic variable files; its files are copied into the data folder of v2. The test checks: the expression texts are converted on load (`x := 1.50` becomes `x := "1.50"` and the evaluated result is the text `1.50`, not the number 1.5); a variable of each kind is set and read back in the same instance with the right location (`instance`, `thread`, `global`, `static`; `builtin` for `A_AhfVersion`); after a kill of the engine and after an orderly restart of the session the `global` and `static` variables (also those of the v1 files) are present with their values and the instance and thread variables are gone; the copy of the v1 folder has the same file list and the same hashes at the end. The test first failed because the test element could not set a thread variable; `Action_TestSetVar` now takes a `location` in a set step, and a probe reports the location of the variable. Not checked: the real `%APPDATA%\AutoHotFlow` of the owner (not touched on purpose; the protection for it is the default folder of E33), and that a v1 process can read what v2 wrote.
- **Acceptance runs (task 3),** on the code state of the end of S1 (the commits after `1783e67` changed only documents):

| Run | Arguments | Result | Runtime |
|---|---|---|---|
| serial | `tests -q -n 0 --all -m "not gui"` | exit 0, 1120 passed, 1 skipped, 2 xfailed (F-17, F-85 marks), 19 deselected (16 stress, 3 gui); no INTERNALERROR | 772 s (12:52) |
| parallel | `tests -q --all -m "not gui"` (4 workers) | exit 0, 1120 passed, 1 skipped, 2 xfailed; no INTERNALERROR | 200 s (3:19) |
| stress | `tests -q -m stress` | **exit 1**, 14 passed, 1 failed; no INTERNALERROR | 268 s (4:27) |

  `--all` alone includes 3 gui tests; they were excluded with `-m "not gui"` (`doc/TEST-STRATEGY.md` section 6). The failed test is `tests/stress/test_big_flows.py` with 200 flows: the largest answer to a snapshot request during the load took 2326 ms (budget 1000 ms), and the time to `evt.engine.ready` was 59.35 s (45.3 s in the measurement of WI-24 before phase 3, largest answer then 506 ms). Everything else in that test held. OPEN-ITEMS F-268.
- **Documents (task 4):** `doc/EXPRESSION-LANGUAGE.md` was complete in content (WI-37 to WI-42 kept it up to date); fixed: stale references to work items that are done, the decision about unsupported syntax, the E34 difference, the status line. `doc/ARCHITECTURE.md`: sections 4 (owner of the parse cache), 7 (write format after E21) and 8 (folder tree with `engine/`, `tools/`, `assets/`). `doc/ELEMENT-API-V2.md`: the alias `VarLocation`, what R4 will change. `doc/MIGRATION.md`: M-48 got the defaults at evaluation (the only deviation in the result sections of WI-40 to WI-42 without an entry; WI-36 to WI-39 have no result section, their deviations are M-24 to M-37; no duplicates). `doc/TEST-STRATEGY.md`: the tests of S1, the comparison with v2, the runtime of the acceptance. `doc/PROTOCOL.md`: checked, the messages of S1 are listed (4.2 `cmd.flow.save` and `strictTypes`, 4.5 `evaluated`, 4.6 `cmd.storage.var.*` and the engine options); no change. `doc/HOW-TO.md`: no entry missing, none added. `AGENTS.md`: current state. `work_items/STATUS.md` and `HANDOVER.md` do not exist; the status of phase 3 is in `work_items/phase3/STATUS.md`, which belongs to the orchestrator and was not changed.
- **Owner's review (acceptance criterion):** the deviation catalog (WI-39) was accepted by the owner on 2026-10-14 (status book). For the MIGRATION entries M-38 to M-48 (WI-40 to WI-42) only M-43 is recorded as confirmed (assumed: the others not yet seen).

### Retrospective

Sizes are the ones in the README (M, M, M, L, L, M, M, S). Result per package, from `git log --grep` on `v2-port` (verified), added lines and commits: WI-36 6890 (9, mostly generated expected data), WI-37 3388 (10), WI-38 1621 (5), WI-39 2034 (7), WI-40 1921 (7), WI-41 1063 (6), WI-42 2108 (10). The dates of the commits cannot be used (the branches were rebased); the durations below are assumed from the run IDs in the status book.

What the estimates missed:

1. **The documents and decisions around the code, not the code.** S1 added 25 entries to the MIGRATION table (M-24 to M-48), and WI-42 had to take over a decision that came in the middle (E34, `strictTypes`, F-105, 2026-10-14). The packages were sized by code. WI-42 (M) had the most commits (10) and changed the protocol (`evaluated`), the flow format (`strictTypes`) and a tool (`run_suite.py`). (verified from the commits)
2. **The test tooling around the golden data.** WI-36 (M) is the largest by lines, and WI-39 and WI-40 each needed a v2 side of the comparison (harness, classes, `golden_compare.py`) that no package named. The comparison with v2 is what makes the catalog trustworthy; it should have been a package of its own. (verified)
3. **Waiting, not working.** The packages took between minutes and an hour of agent time each (assumed), but WI-41 to WI-43 stretched over most of 2026-10-14 because of verifier and bug hunter rounds and decisions (assumed from the run IDs between 07:16 and 17:29). The plan has no place for review rounds.
4. **Numbers in the plan that were wrong.** 14 own built-in variables (it is 13, WI-40); golden data `evalparam` was planned and not done (WI-42). (verified)
5. **A cost that appeared only in the acceptance:** the load of many flows got slower (F-268, assumed to come from the conversion at load or from the variable loading). The stress tier ran for the first time on S1 here; nobody had a reason to run it earlier. Lesson: the stress run belongs at the end of a package that adds work to the load path of the engine (WI-39 and WI-41 were such packages), not only at the end of a step.

For S2 (owner's detailing), besides the rows of the plan:

- **R4, `ctx.Request`, variables in the worker** (M-45 is provisional): decide the form of the import list; `GetVar` of a worker then no longer reads a copy.
- **Loop variables at process level:** loops need real loop elements; WI-40 tested the loop stack only in unit tests. Belongs to the core set (loops).
- **F-268 before more classes become known:** every class that S2 registers makes the load convert more elements. Measure the load phase first, then decide (stagger, or convert on first use).
- **A message to read and change variables from a client** (ARCHITECTURE 4.2, pause: "clients can read and change all variables of an instance"): not built, in no package yet (assumed; not searched in all documents).
- **`V1Syntax` per ported element:** the conversion of a parameter that the element evaluates itself depends on the class naming it. `tools/convert_element.py` should warn when a v1 element calls `x_EvaluateExpression` or `x_EvaluateScript` on a parameter without an expression content type (assumed risk, not checked in the v1 elements).
- **Small open items:** F-255 (`#Warn` in the include list of a unit test), F-235 (flush beyond the limit of the peer), `evalparam` golden data, `A_IPAddress*` and `A_Caret*` not compared with v1, a flow that starts before `evt.engine.ready` can see missing variables, the private golden corpus was never run (nothing present).
