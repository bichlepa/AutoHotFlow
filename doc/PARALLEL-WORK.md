# Parallel work

Status: 2026-10-16. The tools are tested (`tests/test_new_workspace.py`, `tests/test_run_suite.py`). The procedure has run in eight orchestrator sessions with up to four agents at the same time (`doc/ORCHESTRATOR.md`). Lessons from that use go into section 7.

## 1. Principle

**One agent, one workspace, one branch.** A workspace is a git worktree with its own branch `wip/<name>`. Agents never share a working tree. Long test runs happen on a frozen state (`tools/run_suite.py`), so nobody edits the code that a run is testing.

```
python tools/new_workspace.py <name> [--from <ref>]     # branch wip/<name> and the folder ..\AutoHotFlow-wt\<name>
python tools/new_workspace.py --list                    # all workspaces: commits ahead/behind v2-port, changes
python tools/new_workspace.py --remove <name>           # worktree away; the branch only when its changes are on v2-port
```

The tool works from the main checkout and from inside a workspace. VS Code tasks: `Tool: new workspace`, `Tool: list workspaces`, `Tool: remove workspace`.

## 2. Rules

1. Work only in your own workspace. Never change the main checkout or another workspace. The one exception: the test tooling (`tests/conftest.py`, WI-0059) writes the run history into `temp/history/` of the main checkout, an ignored folder without tracked content, so that the runs of every workspace land in one place. Nothing else may write there, and nobody writes there by hand.
2. Commit on your branch (`wip/<name>`), small commits as in AGENTS.md rule 7. Do not merge into `v2-port` yourself; the integrator does.
3. Run tests from your workspace: the fast tier directly (`python -m pytest tests -q`), everything that takes minutes through `python tools/run_suite.py --with-changes` in the background. A second agent tests your branch with `--ref wip/<name>`.
4. No `gui` tests and no desktop automation unless the project owner agrees: windows and focus belong to one session at a time.
5. Start every process of a test with `--data=<temp dir>` (the tests do this; `conftest.py` fails a test that touches the default directory). Never start the product against `%APPDATA%\AutoHotFlow` from an agent.
6. Files that many tasks touch (section 4) get **appended** entries only; do not reorder or reformat them.
7. State what is verified, assumed, not checked (AGENTS.md rule 6). A test result belongs to a code state: name the commit, or "HEAD + uncommitted changes" for `--with-changes`.

## 3. Roles

**Implementer.** Gets a task, creates a workspace, changes code and tests, runs the fast tier and the tests of the affected group, commits. Result: the branch, a short list of what changed, which tests ran on which commit, what was not checked. Interface changes (`doc/PROTOCOL.md`) are their own first commit, so others can see them early.

**Bug hunter.** Result is a *finding*, not a fix, unless the project owner asked for the fix.
1. Reproduce on a fixed commit: `python tools/run_suite.py --ref <sha> -- <test path>::<test> -q -n 0`. A flaky test is run several times (a shell loop around the command) and the failure rate is stated, for example 3 of 20.
2. Reduce it to one test in the own workspace. A test that fails for a known reason is committed on the branch and marked `xfail(strict=True, reason="F-nn ...")`, so it turns loud when the bug is fixed.
3. Find the introducing commit: in the own workspace `git bisect start <bad> <good>` and `git bisect run python -m pytest <test> -q -n 0` (the workspace is yours, bisect may move its HEAD).
4. Report: symptom, repro command, failure rate, cause (verified / assumed), first bad commit, proposed fix. Appending the entry to `doc/OPEN-ITEMS.md` is part of the branch.

**Reviewer.** Reviews a finished branch before it is integrated (ORCHESTRATOR section 3d): the diff against `v2-port`, the task and the author's report. It works in the branch's workspace after the author has finished, fixes small local findings itself (commit `Review fix: ...`) and gives larger ones back to the author. Result: `APPROVED`, `APPROVED WITH FIXES` or `CHANGES REQUESTED` with a list.

**Verification** of the integrated state is a script, not a role: `python tools/verify.py --ref <commit> --auto` runs the tiers that the changed paths need through `run_suite.py` on the frozen commit and prints a verdict (ORCHESTRATOR section 4). New commits on `v2-port` during the runs do not change the tested state.

**Tester.** Runs suites on branches and on the base for comparison, with the same arguments: `python tools/run_suite.py --ref v2-port -- tests -q --all` and `... --ref wip/<name> ...`. A failed test is run again alone (`python tools/recheck.py <run id>`) before it is reported, and a failure that also occurs on the base is not a regression of the branch. Report: commit, command, counts, the failures with the run log folder (`%TEMP%\ahf_runs\<id>\pytest-log`).

**Integrator** (the project owner, or one agent that has been asked). The history of `v2-port` stays linear: no merge commits and no temporary branches in the graph. In the main checkout on `v2-port`:
```
git rebase v2-port                                                # in the workspace of the branch, if v2-port has moved
python tools/renumber_findings.py --commit                        # in the workspace: provisional F-9nnn* get final IDs
git cherry-pick v2-port..wip/<name>                               # in the main checkout (conflicts: section 4)
python tools/new_workspace.py --remove <name>                     # worktree away, branch deleted: its patches are on v2-port
python tools/verify.py --ref <new v2-port tip> --auto             # verification of the integrated state
```
`git cherry-pick` is used instead of `git rebase` because the branch is checked out in its workspace and git does not rebase a branch that another worktree holds. Branches are taken over one after another; the next one is tested again on the new `v2-port` (a cherry-pick can succeed without a conflict and still break a test), because its earlier result was for a different base. When the tree of `v2-port` after the cherry-picks equals the tree that was tested (`git rev-parse HEAD^{tree}`), that result still holds.

## 4. Files with a high conflict risk

| File | Rule |
|---|---|
| `doc/OPEN-ITEMS.md`, `doc/howto/*.md` | new entries at the end of their section (a HOW-TO entry at the end of its category file); new findings get provisional IDs `F-9nnn*`; the integrator gives them final numbers with `tools/renumber_findings.py` (ORCHESTRATOR.md section 2) |
| `doc/PROTOCOL.md` | one commit per interface change, early; the same message type is never added by two branches |
| `.vscode/tasks.json` | new tasks at the end of their group |
| `doc/REQUIREMENTS.md`, `doc/REQUIREMENTS-INDEX.md` | change only the requirements of the own task. The index is generated: never resolve a conflict in it by hand; resolve the source, then run `python tools/doc_index.py` |
| `doc/DOC-INDEX.md` | generated by `tools/doc_index.py`; a conflict is resolved by running the tool |
| `tests/conftest.py`, `tests/support/` | changes are small and separate; the foundation tier runs before the merge |
| `AGENTS.md`, `doc/TEST-STRATEGY.md` | only the project owner or the integrator. Other agents only if directed by the user |

## 5. Load and limits

- **Agents no longer coordinate their test runs by hand (WI-0059).** Every pytest run, direct or through `run_suite`, goes through the machine-wide admission: the workers of all runs together stay at or below `AHF_MAX_WORKERS` (default cores − 2), a run waits for free slots and says so (`[admission] waiting: ...`), and a run whose `-m` selects stress, soak or idle tests waits for an idle machine and blocks the others (`-m "not stress"` does not). Details: `doc/TEST-STRATEGY.md` section 6, "Admission, load figures and run history".
- `tools/run_suite.py` in addition allows 2 of its runs at the same time with 4 workers each (fewer when the admission has fewer free slots). This is a budget, not a guarantee: timing tests (`scaled()`) can become unstable on a loaded machine, and programs outside the test runs are not admitted. Every run prints the load of its red tests and keeps it in the history; a failure that appears only under parallel load is rerun alone before it counts (`python tools/recheck.py <run id>`), and `python tools/test_history.py --flaky` shows tests that were red and green at the same commit. Use `--max-runs 1` for a clean comparison.
- A workspace contains only what git tracks. Everything a test needs is in `tests/data`; a run in a fresh worktree shows a missing dependency as a failure, which is the intended check.
- Agents do not share a desktop session cleanly. GUI work (manual checks, `gui` tests) is done by one party at a time.
- Disk: every workspace is a full checkout without history; remove finished ones.

## 6. Not covered

- Agents do not talk to each other. Coordination goes through branches, the finding entries and the integrator.
- Nothing prevents an agent from breaking rule 1; the tools do not enforce it.
- The load of an implementer, a bug hunter and a tester at the same time on one machine is unmeasured beyond the first trial (section 7).

## 7. Lessons from use (2026-10-13 to 2026-10-16)

The first trial (2026-10-13: one implementer, one bug hunter, a tester, four branches integrated, 782 passed) and eight orchestrator sessions showed:

- **A test failure under load can end the whole run.** Once the diagnosis collection of `conftest.py` raised inside the report hook, xdist stopped (INTERNALERROR, exit 3) and about 80 tests did not run (fixed). **Look at the exit code and at `INTERNALERROR` in `output.txt`, not only at the counts.**
- **Git stores `tests/data/flows` byte-exact (CRLF), the older folders normalized (LF).** Comparing git blobs of a moved file shows a difference although the content is the same; compare working-tree files or normalize line ends first.
- **Scripted edits.** A replace string with `\n` does not match a file with `\r\n`. Use the editor tool, or read and write with `newline=""`.
- **Loops in the background.** A shell loop started with `&` in the tool shell ended with the command that started it. Put repeated runs in a script file and run it in the foreground (with a timeout) or as a background task of its own.
- **`-n`.** `run_suite.py` puts its own `-n 4` before the pytest arguments, so a later `-n 0` of the caller wins. This is intended.
- **A race is shown with a deterministic test** (freeze the dependency), not with load: load in a trial is rarely high enough to provoke it.
- **The saved run log of a failure can disappear.** Copy the evidence of a finding into the finding entry.
- **Budget.** Cold starts of agents (each read about 60k tokens of documents), verifier agents whose runs were almost always green, bug-hunter rounds about timing tolerances under load, and a status log that grew to 59 KB used much of the budget. Hence ORCHESTRATOR version 2: short reading lists, `verify.py`, hunters only on real risks, a status book with the current state only, haiku by default with a sonnet review.
