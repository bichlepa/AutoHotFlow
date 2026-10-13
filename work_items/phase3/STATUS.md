# Phase 3 status book (orchestrator)

Kept by the orchestrator as described in `doc/ORCHESTRATOR.md`, section 10. Branch `v2-port`. Nothing is pushed.

Session start: 2026-10-13, work-item mode (no wishes). Main checkout clean, on `v2-port` (tip `b1227f8` at start), no other workspaces.

## Work items (S1)

| WI | Title | State | Model | Branch / workspace | Commit | Run ID | Date | Note |
|---|---|---|---|---|---|---|---|---|
| WI-36 | Golden data from v1 | in progress | sonnet (implementer) | `wip/wi-36` | | | 2026-10-13 | starts after WI-34 (done) |
| WI-37 | Expression language v2: spec, tokenizer, parser | blocked | | | | | 2026-10-13 | spec depends on open questions 1, 2, 3, 6 of the phase 3 README (unanswered) |
| WI-38 | Evaluator | blocked | | | | | 2026-10-13 | depends on WI-37 (blocked) and questions 1, 2, 3, 6 |
| WI-39 | Converter v1 expressions | blocked | | | | | 2026-10-13 | depends on WI-36, WI-37, WI-38 |
| WI-40 | Variable model in the engine | blocked | | | | | 2026-10-13 | depends on WI-38 |
| WI-41 | global/static permanent, data folder | blocked | | | | | 2026-10-13 | depends on WI-40; open question 4 (default data folder) |
| WI-42 | Parameter evaluation and ctx API | blocked | | | | | 2026-10-13 | depends on WI-38, WI-39, WI-40 |
| WI-43 | Acceptance S1 | blocked | | | | | 2026-10-13 | depends on all |

Blocked = not started because of the dependency named in the note. Open questions of `work_items/phase3/README.md` are answered by the project owner; none is answered yet.

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

Hunter run 2 (2026-10-13) worked on two entries (F-25, F-51 together) and stopped.

Hunter run 1 (2026-10-13) worked on two entries and stopped. Candidates not looked at yet: F-02, F-13, F-17, F-18, F-20, F-23, F-25, F-28, F-29, F-30, F-35, F-36, F-45, F-47, F-48*, F-49*, F-50*, F-51*.

## Review log

| Area | Date | Commit | Result |
|---|---|---|---|

## Integrations

| Branch | Commits | Date | Commit on v2-port | Run ID | Verifier |
|---|---|---|---|---|---|
| wip/hunt-1 | 183c561, 6d635cc | 2026-10-13 | 5e16445, 7161777 (cherry-pick, no conflict) | run 20261013-180408-71617779, commit 7161777 | fast tier green: 298 passed, exit 0, no INTERNALERROR; arch check 0 violations (run on the main checkout, not on the frozen commit) |
| wip/hunt-2 | 2675105, 68b42d8 | 2026-10-13 | c292dfb, fdcae63 (cherry-pick, no conflict) | fast run 20261013-180755-fdcae630 (300 passed), slow run 20261013-180831-fdcae630 (85 passed), commit fdcae63 | both exit 0, no INTERNALERROR; arch check 0 violations |

## Decisions taken by the orchestrator

(none yet)
