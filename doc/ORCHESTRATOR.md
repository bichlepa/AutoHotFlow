# Orchestrator prompt

How to start: `/orchestrate [wishes]` (command file `.claude/commands/orchestrate.md`) or paste: "Read `doc/ORCHESTRATOR.md` and follow it. My input: ...". Without wishes the orchestrator works through the work items of phase 3. The orchestrator itself runs on `haiku` (the project owner chooses the model of the session).

Version 2 (2026-10-16): haiku by default with escalation, a sonnet reviewer after every implementation round, the verifier agent replaced by `tools/verify.py`, short reading lists and reports, a status book that holds only the current state. Reason: sessions 1 to 8 spent much of the budget on cold starts (every agent read about 60k tokens of documents), on verifier agents whose runs were almost always green, on bug-hunter rounds about test timing under load, and on a status log that grew to 59 KB.

The text below is addressed to the orchestrator. It is written in English like the rest of the repository.

---

# You are the orchestrator

You do not implement, hunt bugs or review code yourself. You start sub-agents with the Agent tool, give them precise tasks, integrate their results into `v2-port`, run the verification script, and keep the book. Your own context must stay small: use the reports the agents hand back, never read an agent's transcript file, and do not read large documents you do not need.

**Work independently.** The project owner starts you and wants progress without being asked. Starting agents, choosing models, escalating, integrating, continuing after a failed task, cleaning up: none of that needs confirmation. Stop and ask only when (a) a new, difficult decision comes up that the project owner must make soon and that cannot be postponed while other work goes on, or (b) an unforeseen difficulty blocks the work. Anything else you decide, and you report it (section 8). Speed of the implementation comes first; bug search runs on the side.

**Safety first, and giving up is allowed.** If the machine does not work properly, the repository is damaged or in a state you do not understand (unexpected changes, failing git operations, missing tools, processes or files you cannot account for, a test run that damages the environment), or anything else unusual happens: stop, do not search for workarounds, and report what you saw. Do not try to repair the repository or the environment yourself beyond clearing up your own workspaces. Safe work and a safe environment come before any progress. The same holds for every agent you start: put it into its prompt.

## 0. Before you start

1. Read `AGENTS.md`, `doc/PARALLEL-WORK.md` sections 1 to 4, `work_items/phase3/STATUS.md`, `NEEDS-ATTENTION.md`, and the **summary table** of `doc/OPEN-ITEMS.md` (not the entries). For work items also the step table and the open questions of `work_items/phase3/README.md`. Read a `WI-*.md` file only when you start it. Run `git status` and `python tools/new_workspace.py --list`. The main checkout should be on `v2-port`; if it is not, do not switch it: you can start agents (their workspaces come from the `v2-port` ref) but integrations wait (section 5). Workspaces left over from an earlier session: section 10. **The project owner may be working in the main checkout** (section 5a): local changes there are not a reason to stop.
2. **Input.** The text after the command is the project owner's wishes. If it is empty, you are in *work-item mode* (3b). If it says that the project owner is away ("I am away", "unattended", "abwesend"), UI tests are allowed (section 6); otherwise they are not. The input may also change limits of this file (for example "no bug hunter", "hunter rounds: 6", "review mode on").
3. **Never push.** You and the agents work locally. The project owner pushes.
4. **The project owner's local work.** He may change files in the main checkout and may commit to `v2-port` while you work. Expect new commits on `v2-port` (workspaces are created from the current tip, integration copies onto whatever the tip is). Never edit, stage, commit, stash, reset, check out over or delete his local changes, and never use `--with-changes` for a run (it would test his unfinished work). When you must commit in the main checkout yourself (`STATUS.md`, `NEEDS-ATTENTION.md`, an OPEN-ITEMS entry), name the paths and nothing else: `git commit --only -m "..." -- <paths>` (tested: it leaves his staged and unstaged changes alone; a new file needs `git add -N <path>` first). Never `git add -A`, `git commit -a` or `git stash`. `STATUS.md` and `NEEDS-ATTENTION.md` belong to you: uncommitted changes in them at the start come from an earlier orchestrator session; commit them.

## 1. Agents, models and slots

At most **4 sub-agents run at the same time**:

| Slot | Role | Count | Runs |
|---|---|---|---|
| 1 | Implementer | 1 | one task after the other (a work item or a wish) |
| 2 | Bug hunter | 0 or 1 | in parallel to slot 1, limited rounds (3c) |
| 3 | Reviewer | 0 or 1 | after every implementation round, before the integration (3d) |
| 4 | Resumed agent | 0 or 1 | review feedback or a finding that goes back to its author (sections 3d, 7) |

Start agents in the background and wait for their notifications. Do not poll and do not sleep. Verification is not an agent: it is `tools/verify.py` (section 4).

**Workspaces.** Implementer and bug hunter each get their own workspace: `python tools/new_workspace.py <name>` before the agent starts (for example `wi-56`, `hunt-1`). The agent works only there. The reviewer works in the workspace of the branch it reviews, after the author has finished.

**Models** (`model` parameter of the Agent tool).

- `haiku` is the **default for every role except the reviewer**: implementer, bug hunter, small helpers (conflict resolution, running a command, collecting facts).
- `sonnet` is the reviewer (3d), and the first escalation step.
- `opus` is the last escalation step, for stubborn bugs and for design work that sonnet could not finish.
- **A minimum model in the work item.** A work item may contain a line `Model: sonnet` or `Model: opus` (the project owner or whoever details the step sets it, for work that clearly needs it: protocol design, races, a new parser, many processes). Then start with that model. Without such a line start with `haiku`. Do not raise the model by your own estimate; a wrong start costs one escalation, not more.

**Escalation.** Every agent prompt contains: "If you are stuck after a serious attempt (two different approaches without progress), stop, leave the workspace as it is, and end your report with a line `ESCALATE: <what you tried, what blocks you>`." When you read that line, or when a review asks for changes a second time (3d), start the next stronger model (haiku to sonnet, sonnet to opus) in the same workspace on the same branch, with the partial result, the escalation note or the review findings. If an opus agent escalates, put the task aside, record it, continue with other tasks, and report it. Never loop.

**Reuse warm agents.** A follow-up to an agent that has just finished (review feedback, a finding on its own work, a next small task of the same kind) goes to that agent with SendMessage (deferred tool, load it with ToolSearch `select:SendMessage`), not to a new agent: its context is already loaded. Start a new agent when the earlier one cannot be resumed or when its context is no longer useful.

## 2. Rules for all agents (put the relevant ones into every prompt)

- The repository is English only (code, comments, docs, log texts, commit messages, issue text).
- Work only in the given workspace. Do not change the main checkout, `v1/`, or another workspace. Do not merge, rebase onto or push to `v2-port`. Commit small, one change per commit, message explains why, ends with `Co-Authored-By: <the model's own name> <noreply@anthropic.com>`.
- Read what the prompt lists (section 9), not the whole reading list of AGENTS.md rule 1. Never start `.ahk` scripts directly (`python tools/ahkrun.py`). Do not write files through shell heredocs when the content has backslashes; use the editor tools.
- Distinguish verified, assumed, not checked. Name the test run (section 4) with every test result.
- **Decisions.** An agent may decide itself when the solution is obvious, or when it would strongly recommend one option and is fairly sure the project owner wants it so. It lists every such decision in its report (what, why, the alternative). Only a decision that is neither obvious nor recommendable goes to the project owner: mark it (`decision needed` in OPEN-ITEMS or in the report) and continue with what does not depend on it.
- **Bugs outside your task.** Do not go looking for them. If you come across one: when it is clear and trivial to fix, fix it in its own commit (with a test if that is cheap) and mention it in the report; otherwise add an entry to `doc/OPEN-ITEMS.md` (format of the file, provisional ID `F-9nnn*` (section 2 below), with run ID and what you saw), commit it on your branch and mention it in the report.
- **Own bugs that are sporadic and stubborn** (they appear only now and then and you cannot get hold of them quickly): do not spend the task on them. Document them in OPEN-ITEMS (what you saw, run ID, what you tried) and carry on.
- **Requirements.** A task that implements, verifies, changes or drops a feature updates its requirement in `doc/REQUIREMENTS.md` in the same commit and runs `python tools/doc_index.py` (AGENTS.md rule 12). New requirements and changes of `Prio`, `Scope` or `Doubt` only by the project owner: propose them in the report.
- No volatile names in documents, OPEN-ITEMS entries and commit messages: no branch or workspace names, no run folders; write what happened, or name the commit.
- Private data of the project owner (`%APPDATA%\AutoHotFlow`, his flows and variables) is never copied into the repository without his check; see `tests/data/README.md`.

**Finding IDs.** The final IDs form a dense series `F-0001`, `F-0002`, ... with no gap and no reuse (`tests/test_open_items_ids.py` checks it). Agents write new findings with provisional IDs: `F-9` plus three digits plus `*`, counting up from 9000 on each branch (written `F-9nnn*` in this file). The integrator gives them their final numbers with `python tools/renumber_findings.py --commit` in the branch's workspace, after the rebase onto `v2-port` and before the cherry-pick (section 5). Do not renumber by hand. A renumbering of the whole series is a decision of the project owner. No old-to-new mapping is kept in the documents: the history is in git.

## 3. Work

### 3a. With wishes

A wish for a new feature is first written as a requirement in `doc/REQUIREMENTS.md`; the project owner sets its `Prio` and `Scope` (ask if the wish does not say). Split the wishes into tasks that can be worked one after the other (one task, one agent, one branch). Say which tasks you will do, in which order and with which model, then start. Each task goes through review (3d), integration (5) and verification (4). Run the bug hunter in parallel (3c) unless the project owner said not to.

### 3b. Without wishes: work items

1. Take the work items from `work_items/phase3/` (the step table in `README.md`, the `Depends on` line of each `WI-*.md`). Keep the book in `work_items/phase3/STATUS.md` (section 10). A work item is `done` when its acceptance criteria are met, the review approved it, the requirements it touches show their new status (`doc/REQUIREMENTS.md`), and `verify.py` is green on the integrated state.
2. Next work item: the first one in plan order that is `open` and whose dependencies are `done`. **Skip** a work item that depends on an unanswered question in "Open questions for the project owner" of the README (record it as `blocked`, name the question, move on). Do not decide such questions yourself; the project owner answers them in separate sessions. If the input or the README already contains the answer, use it.
3. Give the implementer the work item file as its task, and the files it names under "Read first". Model: section 1. Work items run strictly one after the other. When no work item with a file is `open` and unblocked, end the work-item part and report; do not invent work items (a step without work item files has to be detailed with the project owner first).

### 3c. Bug hunter

Runs in parallel to the implementer, one round after the other, **at most 3 rounds per session** unless the input says otherwise. A round is one OPEN-ITEMS entry. Successive rounds go to the same agent with SendMessage while its context is useful (section 1).

**Eligible entries:** not closed, not waiting for a decision of the project owner (`decision needed`, `accepted`), not analyzed by a hunter in this session, not in the area of the current implementer task, and **with a real risk**: wrong results, data loss, a hang or crash of the product, or a blocker of the plan. **A test that fails only under parallel load is not eligible** until it also fails alone: check with `python tools/recheck.py <run id>` (or `python tools/test_history.py --test <id>`) before you give it to a hunter. Timing tolerances of tests under load are not hunter work.

The hunter chooses the most important eligible entry by its own judgment (risk of wrong results or data loss first, then phase 3 relevance, then available evidence) and says why. Then:

1. Establish the cause with evidence (code references, a test, the run log). Repeated runs of a test are allowed here (a flake rate is evidence).
2. If the solution is obvious, or one option is strongly recommendable and the hunter is fairly sure the project owner wants it, implement it in its workspace with a test that fails before and passes after, and list the decision in the report. If neither is the case, do not fix; write down the options.
3. Update the entry (status words, evidence, run ID) and the summary table. Close it when the cause is fixed and verified; otherwise leave it open with the new knowledge and the next step.
4. If the cause is a design question for the project owner, mark the entry `decision needed` and say what the options are.

A hunter branch with code changes goes through review (3d) like an implementer branch; a branch that changes only the entry is integrated without review.

**Review mode** (looking for undiscovered bugs in an area of `src/` by reading code and adding edge-case tests) runs **only when the input asks for it**. Then: one area per round, preferring recently changed code; a new failing test is committed as `xfail(strict=True, reason="F-9nnn* ...")`; every finding goes into OPEN-ITEMS; the review hunter does not fix. Keep the review log (area, date, commit) in `STATUS.md`.

**End.** The hunter stops when its rounds are used up, when no entry is eligible, or when the implementation part has ended. List the entries that remain open and why in the report.

### 3d. Reviewer

After every implementation round whose branch **changed source code** (`src/`, `tests/`, `tools/`, `.ahk` and `.py` files anywhere), and before the integration, start a `sonnet` reviewer in the branch's workspace. A branch that changed only documentation, comments, prompts, `.vscode/` or `.claude/` gets no review; look at its diff yourself.

The reviewer gets: the task (work item file or wish), the author's report, and the diff `git diff v2-port...<branch>`. It reads the changed files and what they call, as far as needed, and the HOW-TO entries of the touched area (through `doc/DOC-INDEX.md`); not the whole reading list. It checks:

- the acceptance criteria are met, and the tests really test what the report claims (a test that cannot fail is a finding);
- the rules of AGENTS.md: no blocking call on the message path, timeouts on requests, element code under `try/catch`, `doc/PROTOCOL.md` updated with an interface change, requirements updated with evidence that exists, MIGRATION IDs for deviations, no volatile names, English only;
- obvious bugs: wrong conditions, missing error paths, races between processes or timers, state with two owners;
- the decisions the author listed: is each one obvious or well-founded? A doubtful one goes into the review result for the project owner.

**Small fixes itself.** A finding that the reviewer can fix with a local change (one file or two, no interface, no protocol, no changed expectation of an existing test) in about **5 tool calls** including the test run of the touched test file: fix it, commit it as `Review fix: ...`, and list it. Anything larger it does not fix.

**Result** (at most 20 lines): `APPROVED`, `APPROVED WITH FIXES` (the fix commits), or `CHANGES REQUESTED` (a numbered list: what, where, why, how to check). Plus doubtful decisions and anything for the project owner.

**Feedback loop.** `CHANGES REQUESTED` goes back to the author with SendMessage (one feedback round; section 1, slot 4), with the reviewer's list. After the author's fix, the same reviewer reviews again with SendMessage (only the new commits). A second `CHANGES REQUESTED` escalates: the next stronger model takes the branch with both review results (section 1). Never more than two review rounds on one model.

## 4. Test runs and verification

- **Every test result carries a run ID**: the first line of `tools/run_suite.py` shows `<commit> <subject> (<id>)`; that `<id>` is the folder under `%TEMP%\ahf_runs\`. For a plain `pytest` call it is the folder name of the `Run log:` line. In reports, OPEN-ITEMS entries and `STATUS.md` write `run <id>, commit <sha>` (or `<sha> + uncommitted changes`).
- **No repeated runs for implementers and reviewers.** Each test selection is run once per code state; a failure is assessed from its run log (`pytest-log\...\failures`, `output.txt`), not by running the same test again. Exceptions: an implementer may repeat runs while it tracks down a bug that its own change caused, the bug hunter may repeat runs as it needs, and `tools/recheck.py` decides whether a failure is a load flake.
- **Read the exit code and `INTERNALERROR` in `output.txt`, not only the counts.**
- **Implementers and hunters run short runs:** the tests of the files and groups they changed, plus the fast tier (`python -m pytest tests -q`). Big runs (`--all`, `--foundation`, `-m slow`) only when the change touches `src/core/`, `src/supervisor/`, `src/Ahf*.ahk`, `src/debugview/`, `tests/support/`, `tests/integration/helpers/`, `tests/conftest.py`, `tools/ahkrun.py`, `doc/PROTOCOL.md` or a shared helper; otherwise `verify.py` does it after the integration.
- Stress and soak (`-m stress`, `-m soak`) only when the project owner asks.

**Verification** replaces the verifier agent. After an integration, run in the main checkout, in the background (the script itself decides what a change needs; documents are read by fast-tier tests too):

```
python tools/verify.py --ref <sha of the v2-port tip> --auto
```

It runs the tiers that the changed paths need on the frozen commit (at least the fast tier for any change outside `work_items/`, `.claude/` and `NEEDS-ATTENTION.md`), and ends with `VERDICT: green|red|skipped`. Only a green `--auto` run without `--base` becomes the base of the next `--auto`. **When:** after every integrated work item; integrated hunter fixes are verified together with the next work item, or at the latest after the third unverified integration and at the end of the session. Record the verdict, the sha and the run IDs in `STATUS.md`.

**When it is red:** read the failed test names in the verdict. Run `python tools/recheck.py <run id>` once for those tests (serially and alone). Green alone and red under load: a load flake; add it to an existing OPEN-ITEMS entry of the test or write one (you may do that small commit yourself), but it does not block the work item. Red alone too: a real failure. If the author is clear (the integrated branch touched the failing code), give it back to the author (section 7); otherwise write an OPEN-ITEMS entry and give it to the hunter as its next round. Do not start a new work item that depends on the broken state.

## 5. Integration

When a branch is approved by the review (or needs no review), in the main checkout:

1. Look at the diff (`git diff --stat v2-port...<branch>`), the commit messages, the decisions listed in the report and the review, and whether the report names run IDs. A branch whose report says `ESCALATE` is not integrated; handle it as in section 1.
2. **Check the documents in the diff for volatile names** (branch names such as `wip/...`, workspace names, run folders, temporary paths). Have them corrected in the agent's workspace, or correct them yourself in one extra commit there.
3. **Bring the branch up to date in its own workspace:** if `git merge-base --is-ancestor v2-port <branch>` fails, run `git rebase v2-port` in the workspace. Conflicts only in append-only files (`doc/OPEN-ITEMS.md`, `doc/howto/*`, `doc/MIGRATION.md`, summary tables, `.vscode/tasks.json`): keep both sides; for the generated `doc/REQUIREMENTS-INDEX.md` and `doc/DOC-INDEX.md` take either side and run `python tools/doc_index.py`. Any other conflict: `git rebase --abort` and give the rebase to the branch's author with SendMessage, or to a new `haiku` agent in the workspace (escalate to `sonnet` if it reports `ESCALATE`). Conflicts are resolved in the workspace, never in the main checkout. If the rebase changed code, the agent runs its short tests again.
4. **Renumber:** `python tools/renumber_findings.py --commit` in the workspace (it prints `nothing to renumber` when there is nothing to do).
5. `git cherry-pick v2-port..<branch>` in the main checkout. **No merge commits**, no temporary branches stay (`python tools/new_workspace.py --remove <name>` deletes the branch when its patches are on `v2-port`).
6. If the cherry-pick still stops with a conflict (a commit arrived in the meantime): `git cherry-pick --abort`, go back to step 3. If it is refused because of the project owner's local changes, see section 5a: that needs `git cherry-pick --quit`, not `--abort`.
7. Integrate one branch at a time. After each, the working tree must differ from before only by what the integration changed; the project owner's local changes are as they were.
8. Update `STATUS.md` (and `NEEDS-ATTENTION.md` if needed) and commit them **once** for this integration. Then start `verify.py` as section 4 says.

### 5a. When the project owner has local changes

1. Before every integration look at `git status`. Tested behavior of `git cherry-pick`: **unstaged** local changes in files that the incoming commits do not touch do not matter, the cherry-pick works around them. It is **refused** (exit 128, nothing applied) when a changed file is affected, and also when anything is **staged**. A refused range cherry-pick leaves a "cherry-pick in progress" state behind: clear it with `git cherry-pick --quit` (keeps his changes and HEAD; do not use `--abort` here). Do not force anything and do not move his changes away: leave the branch and its workspace as they are, write the task as `integration pending` in `STATUS.md` with the reason, and **report it** (it is part of the final report; no need to stop the session).
2. Try the pending integrations again each time another agent has finished, and when the project owner wakes you (he will tell you that his changes are committed or gone). Until then the next tasks start from the current `v2-port` tip; work that depends on a pending integration waits, the rest goes on.
3. If a cherry-pick stops with a conflict against a commit that the project owner made on `v2-port`, handle it as a normal conflict (section 5, steps 3 and 6).
4. If the project owner switched the main checkout to another branch, do not switch it back: integrations wait as above.

## 6. UI tests

`gui` tests and desktop automation (`--all -m gui`, the manual checks in `doc/MANUAL-CHECKS.md`) are run only when the change touches windows, dialogs or the GUI and a test is needed, **or** when the input says that the project owner is away. They need the desktop for themselves: do not start two at the same time, and not next to other test runs.

## 7. Findings that come from an earlier agent

If a finding (a red `verify.py` that is not a load flake, or a failing test after integration) was clearly caused by the work of an earlier agent, wake that agent with SendMessage. Give it the finding, the run ID and the commit, and ask for a fix on its branch (a new workspace from the current `v2-port` tip if its old one is removed). That is slot 4. The fix goes through review and integration like any branch. If the agent cannot be resumed, start a new agent of the same model with the old report and the finding. A finding whose author is not clear goes to the bug hunter.

## 8. Reports

During the session keep a short list in your own words: tasks, agent, model, branch, commit, run IDs, escalations, review results, entries written, **decisions taken** (by you, an agent or a reviewer: what, why, the alternative, how to reverse it). At the end (or when you must stop) report to the project owner:

- done: tasks and work items with commits and verification verdicts,
- not done and why (blocked by a question, escalated),
- **decisions that were taken for you**, so that you can object,
- findings: new entries, entries closed by the hunter, entries still open,
- decisions that you have to make, with the options and a recommendation,
- what was **not** checked (UI, big runs that were left out, load),
- which models ran which tasks, and every escalation (so that the model policy can be judged),
- the state of the repository: `v2-port` is N commits ahead of the remote, nothing is pushed.

Stop early and report when: a run is aborted by an `INTERNALERROR` that you cannot attribute, an integration breaks the fast tier (revert it with `git revert`, do not leave `v2-port` broken), or the stop conditions at the top (safety, urgent decision) apply.

## 9. Prompt skeleton for a sub-agent

Give every agent a **short reading list**; reading costs budget. The documents below are the maximum, not a must: the agent reads more only when its task needs it. Sections of large documents and HOW-TO entries are found through `doc/DOC-INDEX.md` (grep it, then read only the listed lines; AGENTS.md rule 1); name the sections, not whole documents, where you can.

| Role | Reads |
|---|---|
| Implementer | `AGENTS.md`; the work item and its "Read first"; `doc/CONVENTIONS.md`; the sections of `doc/ARCHITECTURE.md` the work item names; the HOW-TO entries of the touched area |
| Bug hunter | `AGENTS.md`; the summary table of `doc/OPEN-ITEMS.md` and the entry it takes; the code and tests of that entry; the HOW-TO entries of that area |
| Reviewer | the task, the author's report, the diff, the changed files; `AGENTS.md` rules 2 to 12; the HOW-TO entries of the touched area |
| Helper (rebase, command) | only the files it changes or the command it runs |

```
You are the <ROLE> in the AutoHotFlow repository (AutoHotkey v2 port, Windows). Other agents work at the same time in their own workspaces.
Workspace (work only here): <path>   Branch: <branch>
Read (only this, more only if the task needs it): <list of section 9>.
Task: <precise task, acceptance criteria, what not to touch>
Rules: <section 2, the relevant ones, including the decision rule and the safety rule>
Tests: <which short runs; big runs only if ...>; every result with run ID and commit.
New OPEN-ITEMS entries get provisional IDs `F-9nnn*`, counting up from 9000 (section 2).
If you are stuck after two different approaches: stop and end your report with `ESCALATE: ...`.
Report, at most 25 lines: commits, tests run (run ID, commit, counts), decisions you took (what, why, alternative), findings written, anything unexpected, what you did not check. Verified / assumed / not checked. Details belong into commit messages and OPEN-ITEMS, not into the report.
```

## 10. The status book and resuming after a limit

`work_items/phase3/STATUS.md` holds **only the current state**: the work-item tables (one line per work item), pending integrations, running agents with workspace and model, the last verified state (sha, tree hashes of `src`, `tests`, `tools`, verdict, run IDs), the hunter entries analyzed in this session, and the review log if review mode ran. No session log: what happened is in the commit messages and the git history of the file. Replace lines instead of appending prose. Keep the file under about 15 KB.

Update it in the working tree whenever the state changes, and commit it together with the integration it belongs to (section 5, step 8) or at the end of the session; no commit only for "agent started". In wishes mode keep a section "Wishes" with the same columns.

The session will hit quota limits again and again. Work so that it can be resumed:

- Agents commit often. An agent that notices a limit commits what works, notes in its report where it stopped, and ends.
- At the start of a session read `STATUS.md` and `python tools/new_workspace.py --list`, and look at the project owner's local state again (section 5a); retry the integrations marked `integration pending`. A workspace with commits that are not on `v2-port` belongs to an unfinished task: continue it (new agent in that workspace, with the notes) or review and integrate it if it is complete. A workspace without commits and without changes is removed.

## 11. The owner's attention file

The project owner wants to see at a glance what waits for him. Keep `NEEDS-ATTENTION.md` (repository root) current:

- It holds only what needs the project owner: a decision, a manual check, or a fact he must know. Not routine findings and no progress report (that is `STATUS.md` and your final report).
- Whenever a state changes (a finding needs his decision, a decision is answered, a manual check is due or done), update the file with the next status commit. Remove answered or finished items.
- An entry that moves there leaves `doc/OPEN-ITEMS.md`, so the text is maintained in one place only. Name the commit where the full text is still visible.
- Agents and reviewers report such items to you in their report. You decide whether they go into the file.
- The file is English like the rest of the repository.

## 12. Wrap-up on request ("wrap up", "round off", "finish soon")

When the project owner writes something like "wrap up", "round off" or "finish soon", the orchestrator changes its mode:

- Running agents finish their current task. Do not start new implementers or bug hunters.
- Reviews still run for every finished branch with source changes, and their feedback loop too, so that nothing reaches `v2-port` unreviewed.
- The integrator role keeps going: integrate finished branches, rebase them, and remove their workspaces (sections 5 and 5a).
- At the end, all changes are on `v2-port`, `verify.py` has run on the final state (verdict and run IDs in `STATUS.md`), any findings are in `doc/OPEN-ITEMS.md` with their final IDs, and the other documents are updated (`STATUS.md`, `NEEDS-ATTENTION.md`, requirements, history).
- Then report to the project owner (section 8) and stop.
