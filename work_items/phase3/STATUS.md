# Phase 3 status book (orchestrator)

Kept by the orchestrator as described in `doc/ORCHESTRATOR.md`, section 10. Branch `v2-port`. Nothing is pushed.

Session start: 2026-10-13, work-item mode (no wishes). Main checkout clean, on `v2-port` (tip `b1227f8` at start), no other workspaces.

## Work items (S1)

| WI | Title | State | Model | Branch / workspace | Commit | Run ID | Date | Note |
|---|---|---|---|---|---|---|---|---|
| WI-36 | Golden data from v1 | done | sonnet (implementer), haiku (line-ending fix) | integrated: 786a688 to 9ccf5b3; fix 829ce0f | 829ce0f | fast run 20261013-185858-829ce0f4 (336 passed), golden `--check` exit 0 on the main checkout | 2026-10-13 | 2161 cases, 18 groups; `evalparam` not implemented (optional in the work item); findings in `tests/golden/findings.json` |
| WI-37 | Expression language v2: spec, tokenizer, parser | done | sonnet (implementer) | integrated: 0a24b4c to 6023cde | 6023cde | fast run 20261013-192532-6023cded (434 passed, exit 0), arch check 0 violations (live tree) | 2026-10-13 | `src/expr/`, `doc/AUSDRUECKE.md`, L1 tests. Decisions to confirm: unsupported syntax (spec section 15: `%` modulo, `^=`, `%=`, `<>`, `"a""b"`), tree height limit 200. One flaky failure of `test_worker_reports_not_busy_after_a_cancel_too` in an implementer run, not reproduced on the integrated state. |
| WI-38 | Evaluator | open | | | | | 2026-10-13 | depends on WI-37 |
| WI-39 | Converter v1 expressions | open | | | | | 2026-10-13 | depends on WI-36, WI-37, WI-38 |
| WI-40 | Variable model in the engine | open | | | | | 2026-10-13 | depends on WI-38 |
| WI-41 | global/static permanent, data folder | open | | | | | 2026-10-13 | depends on WI-40; E33 (default data folder) is done in `9eb84e0`, the owner's commit, verified: fast run 20261013-182355-9eb84e08 (301 passed), foundation run 20261013-182435-9eb84e08 (437 passed, 1 skipped, not identified), exit 0 both |
| WI-42 | Parameter evaluation and ctx API | open | | | | | 2026-10-13 | depends on WI-38, WI-39, WI-40 |
| WI-43 | Acceptance S1 | open | | | | | 2026-10-13 | depends on all |

Open questions of `work_items/phase3/README.md`: all answered by the project owner on 2026-10-13 (E29 to E33, commit `d423cb9`). No work item is blocked by a question now. Work items run one after the other (ORCHESTRATOR 3b).

Owner's commits on `v2-port` (not made by an agent): `bdae120` (ORCHESTRATOR rule 4: owner's local work), `d423cb9` (answers E29 to E32, WI-37/38/39/41 text), `9eb84e0` (E33: default data folder `%APPDATA%\AutoHotFlow v2`, touches `src/supervisor/`, so the foundation tier must run on it).

## Last verified state

Verified by the verifier: commit `346341f` (F-72, fast run 20261013-192931-346341fd (436 passed), slow run 20261013-193015-346341fd (86 passed), foundation run 20261013-193207-346341fd (439 passed, 1 skipped, the deliberate runner self-check skip), exit 0 each, no INTERNALERROR; architecture check 0 violations on the live tree). Before that, `6023cde` (WI-37, fast run 20261013-192532-6023cded). Before that, `6f4241c` (F-30, fast, slow and foundation runs green, run IDs in the table above). Tree hashes (`git rev-parse <commit>:src <commit>:tests <commit>:tools`):

| Path | Tree hash |
|---|---|
| `src` | `26f183722397c584cd6a05d95676c3654c21bd71` |
| `tests` | `a341ee19a5c644dcb4355daf7bcf797471cc7314` |
| `tools` | `0503826a18037e2f8eaba3aea61d677270f0edb6` |

Verification of `9eb84e0` (before): fast run 20261013-182355-9eb84e08, foundation run 20261013-182435-9eb84e08.

Later commits on `v2-port` after `6f4241c` that did not change these trees: none verified yet. The verifier rule in `doc/ORCHESTRATOR.md` section 3d applies from now on.

## Agents

| Slot | Role | Model | Workspace | Branch | Task | State |
|---|---|---|---|---|---|---|
| 1 | Implementer | sonnet | `wi-36` | `wip/wi-36` | WI-36 | running |
| 2 | Bug hunter | sonnet | `hunt-1` | `wip/hunt-1` | OPEN-ITEMS mode, then review | running |
| 3 | Verifier | - | - | - | after each integration | not started |
| 4 | Resumed agent | - | - | - | - | none |

## ID blocks (OPEN-ITEMS)

Highest F-nn at session start: F-51 (provisional F-48* to F-51*). F-44 was never assigned and stays unused.

| Block | Given to | Range |
|---|---|---|
| A | Implementer WI-36 | F-52 to F-61 |
| B | Bug hunter hunt-1 | F-62 to F-71 |

## Bug hunter log

| Entry | Area | Result | Commit | Run ID |
|---|---|---|---|---|
| F-12 | engine scheduler, empty loop stack | closed, fixed with a unit test (fails before, passes after) | 183c561 (fix), 6d635cc (book) | unit file only, no pytest run ID |
| F-14 | `Ids.Next`, `ExecContext.Finish` | open, re-read, not reproduced; fix in `src/core/` needs owner agreement | 6d635cc | - |

| F-25 | storage log retry time | stall case fixed with a unit test (fails before, passes after); permanent-hold loss still open | 2675105 (fix), 68b42d8 (book), integrated as c292dfb, fdcae63 | run 20261013-180701-17584 (storage integration tests, 32 passed, before integration) |
| F-51 | log line lost under load | open, not proven; probable cause removed for stalls only | 68b42d8 | - |

| F-28 | worker log target | closed: the worker now sets `storage` as its log target; test fails before, passes after | 58e48d2 (fix), integrated as c0ecec5 | run 20261013-181219-14824 (before), 20261013-181230-15192 (after) |
| F-13 | unprotected check-then-act in the engine | open: one real spot (`_counts` in `Executor`) put under `Critical`, no test possible; `WorkerBridge` and `src/core/` parts left alone | ad6ac7d, integrated as b53185a | run 20261013-181310-15232 (engine tests, 52 passed) |

Hunter run 3 (2026-10-13) worked on two entries (F-28, F-13) and stopped. Candidates not looked at: F-02, F-17, F-18, F-20, F-23, F-29, F-30, F-35, F-36, F-45, F-47, F-48*, F-49*, F-50*.

Hunter run 2 (2026-10-13) worked on two entries (F-25, F-51 together) and stopped.

Hunter run 1 (2026-10-13) worked on two entries and stopped. Candidates not looked at yet: F-02, F-13, F-17, F-18, F-20, F-23, F-25, F-28, F-29, F-30, F-35, F-36, F-45, F-47, F-48*, F-49*, F-50*, F-51*.

## Review log

| Area | Date | Commit | Result |
|---|---|---|---|

## Integrations

| Branch | Commits | Date | Commit on v2-port | Run ID | Verifier |
|---|---|---|---|---|---|
| wip/hunt-1 | 183c561, 6d635cc | 2026-10-13 | 5e16445, 7161777 (cherry-pick, no conflict) | run 20261013-180408-71617779, commit 7161777 | fast tier green: 298 passed, exit 0, no INTERNALERROR; arch check 0 violations (run on the main checkout, not on the frozen commit) |
| wip/hunt-4 | 4d97c49, 7efddfc, 9436902 | 2026-10-13 | 1de6658, 2ac9583, 6f4241c (cherry-pick, no conflict) | fast run 20261013-183714-6f4241c4 (301 passed), slow run 20261013-183749-6f4241c4 (85 passed), foundation run 20261013-183932-6f4241c4 (438 passed, 1 skipped, not identified), commit 6f4241c | all exit 0, no INTERNALERROR; arch check 0 violations |
| wip/hunt-3 | 58e48d2, ad6ac7d, 3815990 | 2026-10-13 | c0ecec5, b53185a, d6713f6 (cherry-pick, no conflict) | fast run 20261013-181410-d6713f6a (301 passed), slow run 20261013-181447-d6713f6a (85 passed), commit d6713f6 | both exit 0, no INTERNALERROR; arch check 0 violations |
| wip/hunt-2 | 2675105, 68b42d8 | 2026-10-13 | c292dfb, fdcae63 (cherry-pick, no conflict) | fast run 20261013-180755-fdcae630 (300 passed), slow run 20261013-180831-fdcae630 (85 passed), commit fdcae63 | both exit 0, no INTERNALERROR; arch check 0 violations |

## Decisions of the project owner (2026-10-13)

| Entry | Decision | Recorded in |
|---|---|---|
| F-25 | accepted: a permanently locked log file may lose its batch | OPEN-ITEMS, status `accepted` |
| F-29 | accepted: low impact, the 10 s stay (option (b)); ARCHITECTURE 6.3 still to be written | OPEN-ITEMS, status `accepted` |
| F-36 | closed | OPEN-ITEMS, closed |
| F-43 | decided: implement the recommendation (a child in state `starting` does not hold its shutdown group) | implemented in 03c5ee6, closed in 1d62e4a; verifier green: fast run 20261013-191224-1d62e4ab (336), slow run 20261013-191306-1d62e4ab (86), foundation run 20261013-191456-1d62e4ab (439, 1 skipped = the deliberate skip of the runner self-check) |

## Decisions taken by the orchestrator

- Hunter runs are not limited to two entries per run on principle; the limit of run 1 to 3 was a choice that the procedure does not require.
- WI-36: the golden check on Windows compares line endings; a fix is in progress on a separate workspace (see the WI-36 row).
