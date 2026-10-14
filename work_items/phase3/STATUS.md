# Phase 3 status book (orchestrator)

Kept by the orchestrator as described in `doc/ORCHESTRATOR.md`, section 10. Branch `v2-port`. Nothing is pushed.

Session start: 2026-10-13, work-item mode (no wishes). Main checkout clean, on `v2-port` (tip `b1227f8` at start), no other workspaces.

## Work items (S1)

| WI | Title | State | Model | Branch / workspace | Commit | Run ID | Date | Note |
|---|---|---|---|---|---|---|---|---|
| WI-36 | Golden data from v1 | done | sonnet (implementer), haiku (line-ending fix) | integrated: 786a688 to 9ccf5b3; fix 829ce0f | 829ce0f | fast run 20261013-185858-829ce0f4 (336 passed), golden `--check` exit 0 on the main checkout | 2026-10-13 | 2161 cases, 18 groups; `evalparam` not implemented (optional in the work item); findings in `tests/golden/FINDINGS.md` |
| WI-37 | Expression language v2: spec, tokenizer, parser | done | sonnet (implementer) | integrated: 0a24b4c to 6023cde | 6023cde | fast run 20261013-192532-6023cded (434 passed, exit 0), arch check 0 violations (live tree) | 2026-10-13 | `src/expr/`, `doc/EXPRESSION-LANGUAGE.md` (renamed from the German file name), L1 tests. Decisions to confirm: unsupported syntax (spec section 15: `%` modulo, `^=`, `%=`, `<>`, `"a""b"`), tree height limit 200. One flaky failure of `test_worker_reports_not_busy_after_a_cancel_too` in an implementer run, not reproduced on the integrated state. |
| WI-38 | Evaluator | done | sonnet (implementer) | integrated: ebcb01e to 0506198 (rebased once onto v2-port) | 0506198 | fast run 20261014-061523-4784 (482 passed, exit 0, on the rebased branch); verifier pending | 2026-10-14 | `src/expr/` evaluator, 31 us per typical expression (parse cache hit); decisions to confirm: `missing` field in the result, failed `+=` leaves `""`, text that looks like an integer counts as integer for E29, `mod` added, MIGRATION M-24 to M-26 |
| WI-39 | Converter v1 expressions | done (owner accepted the catalog and the decisions of the implementer, 2026-10-14; F-105 stays open) | sonnet (implementer) | integrated: 7 commits, the last is 1e444c2 (rebased once onto v2-port) | 1e444c2 (first commit 7732b8e) | fast run 20261014-064430-17980 (514 passed, exit 0, rebased branch); verifier pending | 2026-10-14 | 1418 expression/script cases against the golden data: 726 agree after conversion, 490 accepted deviations, 194 depend on the WIP variable model (WI-40), 8 unsupported; open: owner review of the catalog (EXPRESSION-LANGUAGE 15.1), the five unsupported forms, F-105 (E30) decision; private golden cases not checked (no data on the machine) |
| WI-40 | Variable model in the engine | done, verified | opus (implementer) | integrated: deade8e to 84a3912 (7 commits, rebased once onto v2-port) | 84a3912 | fast run 20261014-071610-364 (548 passed, exit 0, on the rebased tree; trees identical to 84a3912); verifier green: fast 20261014-071710-84a39123 (548 passed), slow 20261014-071759-84a39123 (86 passed, 2 xfailed, the F-85 and F-17 marks), arch 0 violations, golden test file in the fast run; foundation not run, no foundation-list file changed since aa81047 (verified there) | 2026-10-14 | `src/engine/vars/`; golden 2161 cases compared, all destination, checkname, replace (389/392 agree, 3 with class) and varset cases agree or have a class; decisions to confirm: M-43 (`object . "x"` gives empty plus warning), no Arrays in variables, SetVar rules, A_LanguageName real name; F-105 still open |
| WI-41 | global/static permanent, data folder | done, verifier running | sonnet (implementer) | integrated: 4f3c3ce to 2c20eff (5 commits, rebased once onto v2-port) | 2c20eff | implementer, before the rebase: fast 20261014-165057-10900 (566 passed), serial 20261014-165356-18628 (566), slow 20261014-165146-91d44148 (86 passed, 1 xfailed, 1 xpassed: F-85/F-17 marks), foundation 20261014-165149-91d44148 (440 passed, 1 skipped). Verifier on 2c20eff: see the verifier row | 2026-10-14 | `src/engine/vars/VarLoader.ahk`, `VarWriter.ahk`; messages kept as `cmd.storage.var.get/set/delete/list`; M-06, M-39; not checked: real data folder, hand start, load of hundreds of variables, standby, ack wait at shutdown | depends on WI-40; E33 (default data folder) is done in `9eb84e0`, the owner's commit, verified: fast run 20261013-182355-9eb84e08 (301 passed), foundation run 20261013-182435-9eb84e08 (437 passed, 1 skipped, not identified), exit 0 both |
| WI-42 | Parameter evaluation and ctx API | open | | | | | 2026-10-13 | depends on WI-38, WI-39, WI-40 |
| WI-43 | Acceptance S1 | open | | | | | 2026-10-13 | depends on all |

Open questions of `work_items/phase3/README.md`: all answered by the project owner on 2026-10-13 (E29 to E33, commit `d423cb9`). No work item is blocked by a question now. Work items run one after the other (ORCHESTRATOR 3b).

Owner's commits on `v2-port` (not made by an agent): `bdae120` (ORCHESTRATOR rule 4: owner's local work), `d423cb9` (answers E29 to E32, WI-37/38/39/41 text), `9eb84e0` (E33: default data folder `%APPDATA%\AutoHotFlow v2`, touches `src/supervisor/`, so the foundation tier must run on it).

## Last verified state

Verified by the verifier (session 2): commit `f0793ce`, no findings, no suspicions. Fast run 20261014-060416-f0793ce2 (436 passed, exit 0), slow run 20261014-060503-f0793ce2 (86 passed, exit 0), foundation run 20261014-060653-f0793ce2 (439 passed, 1 skipped = the deliberate skip of the runner self-check, exit 0), no INTERNALERROR; architecture check exit 0 (94 files, 0 violations). Tree hashes: `src` `5ed42d2a96faeae45924a42a798a392131090a02`, `tests` `4f0b26135dcdf6933f29d1d7fe0f68a131cd0447`, `tools` `0503826a18037e2f8eaba3aea61d677270f0edb6`. Not checked: gui, stress, soak; golden `--check`; open action 4 (three `uncaught/timeout` golden cases).

Earlier verification: commit `346341f` (F-72, fast run 20261013-192931-346341fd (436 passed), slow run 20261013-193015-346341fd (86 passed), foundation run 20261013-193207-346341fd (439 passed, 1 skipped, the deliberate runner self-check skip), exit 0 each, no INTERNALERROR; architecture check 0 violations on the live tree). Before that, `6023cde` (WI-37, fast run 20261013-192532-6023cded). Before that, `6f4241c` (F-30, fast, slow and foundation runs green, run IDs in the table above). Tree hashes (`git rev-parse <commit>:src <commit>:tests <commit>:tools`):

| Path | Tree hash |
|---|---|
| `src` | `26f183722397c584cd6a05d95676c3654c21bd71` |
| `tests` | `a341ee19a5c644dcb4355daf7bcf797471cc7314` |
| `tools` | `0503826a18037e2f8eaba3aea61d677270f0edb6` |

Verification of `9eb84e0` (before): fast run 20261013-182355-9eb84e08, foundation run 20261013-182435-9eb84e08.

Later commits on `v2-port` after `6f4241c` that did not change these trees: none verified yet. The verifier rule in `doc/ORCHESTRATOR.md` section 3d applies from now on.

## Agents

Session 3 start: 2026-10-14, work-item mode, HEAD `26211f2` on `v2-port`, main checkout clean, no workspaces left over. WI-40 is verified (`fb50629`). WI-38 has no separate verifier run; its code is covered by the WI-40 verifier runs (`84a3912`, which contains it). Next: WI-41 (implementer, sonnet, workspace `wi-41`) in parallel with one bug hunter (sonnet, workspace `hunt-6`, excluded: F-17, F-85, storage, engine loading/shutdown, variable model).

| Slot | Role | Model | Workspace | Branch | Task | State |
|---|---|---|---|---|---|---|
| 1 | Implementer | sonnet | wi-41 (removed) | (deleted) | WI-41 | done, integrated |
| 4 | Verifier WI-41 | sonnet | verify-7 (removed) | (deleted) | verification of `2c20eff`: fast run 20261014-165741-2c20effb (566 passed, exit 0), slow run 20261014-165833-2c20effb (86 passed, 2 xfailed, exit 0), foundation run 20261014-170040-2c20effb (443 passed, 1 skipped, exit 0), no INTERNALERROR, arch 0 violations, no findings; tree hashes src `014d55ca`, tests `5a02bc9a`, tools `dd542ea8` | done |
| 1 | Implementer WI-42 | opus | wi-42 | wip/wi-42 | WI-42 (after WI-41; starts from dea1db3) | running |
| 2 | Bug hunter round 4 (review) | sonnet | hunt-7 (removed) | (deleted) | review of WI-41 variable persistence; fixed: object as member key in `VarAccess.Set` (6e13247), shutdown flush after a throwing stop (ab600ef); F-235* open (FlushAll beyond the peer pending limit, low); integrated as 6e13247, ab600ef, 2d57395 | done, verifier running |
| 5 | Verifier round 4 | sonnet | verify-8 (removed) | (deleted) | verification of `2d57395`: fast run 20261014-170405-2d573956 (568 passed, exit 0); slow run 20261014-170456-2d573956: 1 failed (F-236: a killed worker gives no `evt.process.crashed` in the budget), 85 passed, 2 xfailed, exit 1; arch 0 violations; entry F-236 integrated as 505aceb | done, one failure to reproduce |
| 6 | Bug hunter F-236 (reproduce, classify) | sonnet | hunt-8 (removed) | (deleted) | F-236 not reproduced in 8 runs (5 serial, 3 full slow tier); cause unknown; failure diagnostics added to `kill_role`, integrated as 9fcf6fa; entry updated | done, cause open |
| 8 | Integration note | - | - | - | The integration of the hunter branch first stopped in a conflict in the status table of OPEN-ITEMS and the conflict markers were committed on the branch by mistake; corrected in the branch before integration (amended, no markers on `v2-port`). Lesson: pipe `tail` masks the exit code of git; check the exit code and the state of the worktree after every integration step. | recorded |
| 9 | Implementer, scroll position fix for the snapshot text (F-256) | sonnet | dbg-scroll (removed) | (deleted) | `_SetEditKeepView` in `src/debugview/DebugGui.ahk`: first visible line and selection saved and restored, redraw off during the set; integrated as ca9fbc6; foundation run 20261014-172058-b62a3fe5-wc (443 passed, 1 skipped, exit 0, no INTERNALERROR), source tree identical after integration; NOT tested by automated test, owner's manual check pending; horizontal scroll not restored | done, manual check pending |
| 7 | Implementer, snapshot scroll fix (owner's manual check, debug window step 3) | sonnet | dbg-snap (removed) | (deleted) | time moved to its own label in `src/debugview/DebugGui.ahk`, integrated as bfda2d9; foundation run 20261014-171256-9212271f-wc (443 passed, 1 skipped, exit 0) on the tested state, src tree identical after integration, so no new verifier; NOT covered by an automated test; scroll behaviour still needs the owner's manual check (MANUAL-CHECKS section 2 step 3) | done, manual check pending |
| 2 | Bug hunter | sonnet | hunt-6 (removed) | (deleted) | F-18 (pipe DACL restricted to owner and system): fixed and closed, integrated as 9e4aa08, fe00e33, bc30f80 (rebased once onto v2-port, cleanup commit for a run folder name in CLOSED-ITEMS); workspace removed | done, verifier running |
| 3 | Verifier F-18 | sonnet | verify-6 (removed) | (deleted) | verification of `bc30f80`: fast run 20261014-164350-bc30f804 (548 passed, exit 0), slow run 20261014-164436-bc30f804 (86 passed, 2 xfailed, exit 0), foundation run 20261014-164640-bc30f804 (443 passed, 1 skipped, exit 0), no INTERNALERROR, arch 0 violations, no findings; tree hashes src `b07a425b`, tests `24710c35`, tools `dd542ea8` | done |

ID blocks (session 3): implementer WI-41 F-195 to F-204 (none used); bug hunter hunt-6 F-205 to F-214 (none used); verifier verify-6 and verify-7 F-215 to F-224; implementer WI-42 F-225 to F-234; bug hunter hunt-7 F-235 to F-244 (F-235 used); verifier round 4 F-236 (used by the verifier); bug hunter hunt-8 F-245 to F-254. 

Session 2 start: 2026-10-14, work-item mode, HEAD `f0793ce` on `v2-port`, main checkout clean, no workspaces left over. Since the last verified state `346341f`, source/tests changed (WI-36 finding format `769903d`, plus the owner's doc commits): a baseline verification of `f0793ce` is started (verifier, `verify-1`).

| Slot | Role | Model | Workspace | Branch | Task | State |
|---|---|---|---|---|---|---|
| 1 | Implementer | opus | (removed) | (deleted) | WI-40 | done (see the WI-40 row) |
| 2 | Bug hunter | sonnet | (removed) | (deleted) | OPEN-ITEMS round 2: F-73 analysed (decision needed, cause plausible: external close), integrated as 5251c04 | done |
| 2b | Bug hunter | sonnet | (removed) | (deleted) | F-125: test precondition fixed (waits for the log burst, skip otherwise), 11 runs without XPASS; integrated as d354ff5, 107bb65. Tested tree equals v2-port tree (tests `bb0f06e`); slow run 20261014-063319-444 (86 passed, 2 xfailed), fast run 20261014-063423-24212 (482 passed) | done |
| 3 | Verifier | sonnet | (removed) | (deleted) | verification of `1e444c2` (WI-39): fast green (run 20261014-064547-1e444c2d, 514 passed), foundation green (run 20261014-064848-1e444c2d, 439 passed, 1 skipped), slow red by the F-17 strict XPASS again (F-165*, run 20261014-064633-1e444c2d), arch 0 violations; finding integrated as 87b17de | done |
| 4 | Fix (drop strict on the F-17 test, per the F-125 action) | haiku | (removed) | (deleted) | F-125, F-165: strict dropped (e843ebb), notes (a7dc7dd, F-165 action line); tests: file with -m slow run 20261014-065332-17556 (2 xfailed, exit 0), fast run 20261014-065448-19324 (514 passed, exit 0) | done |
| 2 | Bug hunter round 3 | sonnet | (removed) | (deleted) | F-29 follow-up (hello never answered): fix in `src/core/ipc/Peer.ahk` accepted by the owner, integrated as e5542f0, aa81047 (ARCHITECTURE 6.3 sentence); verification running | done, verification pending |
| 3 | Verifier F-29 fix | sonnet | (removed) | (deleted) | verification of `aa81047`: fast 20261014-070717-aa81047f (514 passed), foundation 20261014-070803-aa81047f (440 passed, 1 skipped), slow 20261014-070955-aa81047f (86 passed, 2 xfailed), arch 0 violations, single test with --all 20261014-071204-aa81047f (passed); no findings | done |
| 3 | Verifier WI-40 | sonnet | (removed) | (deleted) | verification of `84a3912`: green, see the WI-40 row | done |

## ID blocks (OPEN-ITEMS)

Highest F-nn at session 2 start: F-74 (provisional F-73*, F-74*). F-44 was never assigned and stays unused.

| Block | Given to | Range |
|---|---|---|
| A | Implementer WI-36 | F-52 to F-61 |
| B | Bug hunter hunt-1 | F-62 to F-71 |
| C | Implementer WI-38 | F-75 to F-84 |
| D | Bug hunter hunt-5 | F-85 to F-94 |
| E | Verifier baseline `f0793ce` | F-95 to F-104 |
| F | Implementer WI-38 | F-75 to F-84 (none used) |
| G | Implementer WI-39 | F-105 to F-114 |
| H | Bug hunter round 2 | F-115 to F-124 |
| I | Verifier `0506198` | F-125 to F-134 (F-125* used) |
| J | Bug hunter F-125 | F-135 to F-144 (used: F-125 fix) |
| - | Next: WI-41 after the WI-40 verification (depends on WI-40 only); WI-42 after WI-41 is not required by the plan order but depends on WI-40 and WI-39 (both done) |
| K | Implementer WI-40 | F-145 to F-154 (none used) |
| N | Verifier WI-40 (`84a3912`) | F-185 to F-194 |
| L | Bug hunter round 3 | F-155 to F-164 |
| M | Verifier WI-39 (`1e444c2`) | F-165 to F-174 |

Open point (assumed, from the WI-41 review, hunter round 4): the supervisor's shutdown deadline for storage was not reviewed; it must leave storage enough time to empty its queue after the engine's flush. Also not checked: a race between the write timer and shutdown (interruption with real threads, assumed tiny).

Decision of the project owner (2026-10-14, confirmed): at shutdown the engine does not wait for storage's answer to the variable writes. A storage crash at that exact moment loses the last changes without a message (FlushAll ignores late errors). Accepted.

Open point (assumed, not tested, from the F-18 review): for an elevated process whose default owner is the Administrators group, a non-elevated client of the same user might be denied by the owner ACE. Not covered by any test. Check when the supervisor runs elevated.

Decisions taken by the WI-41 implementer (listed in its report, to be objected to by the owner): kept the existing message names `cmd.storage.var.get/set/delete/list`; loaded texts stay texts, numbers are written as text (M-39); files written without BOM, read with or without (M-16); no wait for the write acknowledgements at shutdown (storage empties its queue last; assumed acceptable, same class as M-01); test element `Action_TestSetVar` with its own `Plain()` conversion (arch rule).

Known limits of WI-41 (from the report): a flow started before `evt.engine.ready` can see a variable as missing; static variables of flows that are not loaded are not read; no test with the owner's real data folder.

Owner's manual checks (2026-10-14, `doc/MANUAL-CHECKS.md`, not yet committed by the orchestrator; the owner's file): stub steps 1 to 6 pass; debug window steps 1, 2, 4 to 9 pass, step 3 fails (snapshot text jumps to the top on every refresh; the time "Stand ..." is in the same text). Fix in progress (implementer row 7). Open from the owner's notes: the step 1 debug task opens the debug window next to the stub window (doc does not say so); the step 5 exit code comes from the `ahkrun.py` log, not from the VS Code task; step 8 is not fully clear which debug window ended (one "debug gone" entry in the hub log). #Warn dialog from the variable loader: F-255*, open.

## Bug hunter log

| Entry | Area | Result | Commit | Run ID |
|---|---|---|---|---|
| F-18 (session 3) | hub pipe access (DACL) | closed: pipe was readable by Everyone and anonymous; test fails before, passes after; fixed with owner and system only | 9e4aa08, fe00e33, bc30f80 | foundation run on commit 7dc61bc (443 passed, 1 skipped, exit 0), fast run on f444510 (548 passed, exit 0). Not checked: a real second user, an elevated supervisor |
| F-12 | engine scheduler, empty loop stack | closed, fixed with a unit test (fails before, passes after) | 183c561 (fix), 6d635cc (book) | unit file only, no pytest run ID |
| F-14 | `Ids.Next`, `ExecContext.Finish` | open, re-read, not reproduced; fix in `src/core/` needs owner agreement | 6d635cc | - |

| F-25 | storage log retry time | stall case fixed with a unit test (fails before, passes after); permanent-hold loss still open | 2675105 (fix), 68b42d8 (book), integrated as c292dfb, fdcae63 | run 20261013-180701-17584 (storage integration tests, 32 passed, before integration) |
| F-51 | log line lost under load | open, not proven; probable cause removed for stalls only | 68b42d8 | - |

| F-28 | worker log target | closed: the worker now sets `storage` as its log target; test fails before, passes after | 58e48d2 (fix), integrated as c0ecec5 | run 20261013-181219-14824 (before), 20261013-181230-15192 (after) |
| F-13 | unprotected check-then-act in the engine | open: one real spot (`_counts` in `Executor`) put under `Critical`, no test possible; `WorkerBridge` and `src/core/` parts left alone | ad6ac7d, integrated as b53185a | run 20261013-181310-15232 (engine tests, 52 passed) |

Hunter run 4 (session 2, 2026-10-14): F-17 reproduced (chatty role during a 6 s supervisor stall: queue overflow closes the connection, then exit 4 after ORPHAN_MS); new F-85 (a burst of about 3000 log lines closes the link to storage, lines lost). Only xfail tests committed (`tests/fault/test_log_burst.py`, slow tier, integrated as 28f131a); both entries `decision needed` (options: drop and count above a soft limit, batch lines, raise the queue limit). Fast tier green (436 passed, run 20261014-061217-15880). Integrated as 1127f66. **Verifier pending** for 28f131a (tests only, slow tier) together with the next integration.

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
| F-25 | accepted: a permanently locked log file may lose its batch | CLOSED-ITEMS, status `accepted` |
| F-29 | accepted: low impact, the 10 s stay (option (b)); ARCHITECTURE 6.3 still to be written | CLOSED-ITEMS, status `accepted` |
| F-36 | closed | CLOSED-ITEMS, closed |
| F-43 | decided: implement the recommendation (a child in state `starting` does not hold its shutdown group) | implemented in 03c5ee6, closed in 1d62e4a; verifier green: fast run 20261013-191224-1d62e4ab (336), slow run 20261013-191306-1d62e4ab (86), foundation run 20261013-191456-1d62e4ab (439, 1 skipped = the deliberate skip of the runner self-check) |
| F-17 and F-85 (2026-10-14) | project owner follows the recommendation: option (a), log entries droppable and counted above a soft limit; implementation still open | OPEN-ITEMS F-17, F-85 |
| M-43 (2026-10-14) | confirmed by the project owner | MIGRATION M-43 |
| E34 (2026-10-14, F-105) | per-flow option `strictTypes`: migrated flows `false` (v1 behaviour, E25), new flows `true` (type errors become element errors); `f1` warnings visible in the editor in both modes | README E34, WI-42 task 7, OPEN-ITEMS F-105 |
| WI-39 (2026-10-14) | catalog reviewed and accepted; the unsupported forms (`%`, `^=`, `%=`, `<>`, `"a""b"`) stay unsupported; the implementer's decisions (M-27 to M-37, number literals as strings, `formatVersion`/`v1Text`, `cmd.flow.save`, statuses) are accepted; F-105 (E30, empty or missing variable in comparisons) stays open for a later decision | EXPRESSION-LANGUAGE 15.1 to 15.3, MIGRATION M-27 to M-37; open actions removed from OPEN-ITEMS |
| Open actions 1 and 2 of OPEN-ITEMS (2026-10-14) | deleted from the list (rule: finished actions are removed, not marked); the hello follow-up is under review, see the hunter round 3 entry | OPEN-ITEMS open actions |

## Decisions taken by the orchestrator

- Hunter runs are not limited to two entries per run on principle; the limit of run 1 to 3 was a choice that the procedure does not require.
- WI-36: the golden check on Windows compares line endings; a fix is in progress on a separate workspace (see the WI-36 row).
