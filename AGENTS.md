# AGENTS.md

## Language

**The repository is English only**: code, comments, documentation, log texts, commit messages, VS Code task labels and issue/PR texts. This keeps the project open for contributors worldwide.

## What this is

AutoHotFlow (AHF) is being ported from AutoHotkey v1 (AutoHotkey_H with `AhkThread`) to **AutoHotkey v2**. The architecture is rebuilt so that the old deadlocks and race conditions cannot occur by design: **several processes that exchange messages, no shared memory, no global lock**.

## Current state

- Branch `v2-port` (the port). `master` is the working v1.
- Phase 0 (inventory) and phase 1 (design) are done and approved.
- **Phase 2 (walking skeleton) is complete.** Phase 2b (hardening) is complete, and the fix block WI-0030 to WI-0035 is complete with a green acceptance run (WI-0035 cycle 1, code state `2f2e6e5`).
- Not built yet: trigger host (E0006, early in phase 3), editor, real manager, real elements. The GUI of the stub has not been checked by hand.
- **Phase 3 (the v1 feature scope in the new architecture) is approved by the project owner (2026-10-13).** Plan: `work_items/phase3/README.md`. **Step S0001 (expressions and variables, WI-0036 to WI-0042) is implemented**: expression language, converter of v1 expressions, evaluator, variable model, permanent `global`/`static` variables, parameter evaluation and `ctx` API; golden data of v1: 2161 cases, none open. The acceptance WI-0043 is green in the serial and the parallel run; the stress run has one red test (200 big flows, OPEN-ITEMS F-0073), so WI-0043 is not closed. **Step S0002 is detailed (WI-0044 to WI-0058)**; its decisions E0035 to E0039 (v1 is no longer the yardstick) are in `doc/DECISIONS.md`. The open questions of the plan are answered by the project owner in separate sessions; a work item that depends on one waits.
- Requirements: `doc/REQUIREMENTS.md` lists every feature and quality requirement, whether v1 has it, how far v2 is and which step brings it; the generated overview is `doc/REQUIREMENTS-INDEX.md`. Ideas of the project owner for after the port are there too (scope `later`).
- Open findings: `doc/OPEN-ITEMS.md`. Decisions: `doc/DECISIONS.md`. Work-package history: `doc/HISTORY.md`. Full work-item history before the cleanup: git tag `v2-phase2-final` (`git show v2-phase2-final:work_items/STATUS.md`).
- Test timing: `tests/support/timing.py` (`scaled()`; see `doc/TEST-STRATEGY.md`).

## Entry points

- Product: `src/AutoHotFlow.ahk` (the supervisor; includes `src/AhfBoot.ahk`). Every other role has its own entry script `src/entry/<role>.ahk` with only its element classes (`src/entry/generated/`, written by `tools/gen_element_includes.py` from the literal `static Mode` of each class; E0041). The supervisor starts the roles from there.
- Test roles (`echo`, `crasher`, `hanger`, `slow_shutdown`) exist only in the test entries (`tests/integration/helpers/AutoHotFlowTest.ahk` and `tests/integration/helpers/entry/`) with `--test-roles`. Nothing in `src/` includes anything from `tests/`.
- Layout of the v2 code: `doc/ARCHITECTURE.md`, section 8.
- The v1 code lives unchanged in `v1/` (temporary, reference only, **do not change**).

## Decisions (binding, details in `doc/ARCHITECTURE.md`)

- Processes instead of threads: `supervisor` (hub), `storage`, `engine`, `triggerhost`, `manager`, one `editor` per open flow, a `worker` pool.
- IPC over named pipes (frame: length prefix + JSON, wake-up via `PostMessage`), star topology through the supervisor.
- Drawing happens in the editor process behind the `Renderer` interface (separable later).
- Elements run `inline` (engine), `worker` (own process) or `trigger` (trigger host). Dialogs never run in the engine.
- Old flows (`.json`) and variables (`.ahfvd`/`.ahfvar`) must load (E0021). v1 is not the yardstick (E0035): a loaded v1 flow may need small fixes, and every such place is marked with its MIGRATION ID.
- Tests: pytest as the driver (e2e, fault injection, stress) plus small AHK unit tests.

## Folders

| Path | Purpose |
|---|---|
| `doc/` | Lasting documentation (requirements, architecture, protocol, element API v2, test strategy, conventions, migration, how-to AHK v2) |
| `work_items/` | Temporary working papers of phase 3 (plans, work packages). Delete after the port. Earlier work items: tag `v2-phase2-final`. |
| `v1/` | Temporary v1 reference. Removed after the port. |
| `src/`, `tests/`, `tools/`, `assets/` | v2 code (layout: `doc/ARCHITECTURE.md` section 8) |

## Rules for changes

1. Before a task read: this file, `doc/ARCHITECTURE.md` (sections 1 to 6), `doc/CONVENTIONS.md`, then the document for your own task. For AHK v2 code also `doc/HOW-TO.md`. What AutoHotFlow must do and how far v2 is: `doc/REQUIREMENTS-INDEX.md`, and the sections of `doc/REQUIREMENTS.md` that your task touches.
2. No shared mutable state, only messages. Every datum has exactly one owner.
3. No blocking call on the message path (`MsgBox`, file I/O, `RunWait`, `WinWait` without timeout). Every request has a timeout.
4. Do not change anything in `v1/`. Deliberate deviations from v1 behavior go into `doc/MIGRATION.md`.
5. New message types go into `doc/PROTOCOL.md`. Whoever changes an interface updates that document in the same commit.
6. Distinguish **verified** (read or tested), **assumed** and **not checked**. Do not claim anything about code you have not read.
7. Small commits, one change per commit. The commit message explains the why.
8. Element code must never crash the engine: every call under `try/catch`, errors are reported as result `exception`.
9. Difficulties and own mistakes in the AHK v2 implementation go into `doc/HOW-TO.md`: what was hard, what was wrong, what works (format in the file). Each entry carries a status (verified / assumed / not checked). This is not a bug tracker. Good: bugs that could easily come back. Bad: past bugs in a finished module.
10. **VS Code tasks for the project owner:** every call the project owner may want to run by hand (tests, starting the app or a role, tools, manual checks from a guide) gets a task in `.vscode/tasks.json`. Whoever adds or changes such a call (new option, new role, new tool, new test group) updates the task in the same commit. Labels are in English with a prefix (`Test:`, `Start:`, `Tool:`, `Debug:`, `Testdata:`, `Setup:`). Exception to "never start AHK scripts directly": the `Start:` tasks start `AutoHotkey64.exe` directly, without `ahkrun.py` and without timeout, because the owner operates the app (a dialog then blocks until closed). Agents still use `ahkrun.py`.
11. **Never merge.** Rebase or cherry-pick the changes of other branches onto the destination branch, so that the history stays linear and free of unnecessary branch lines. A request to "merge" usually means the user wants a rebase: in that case, rebase.
12. **Requirements stay current.** Whoever implements, verifies, changes or drops a feature updates its requirement in `doc/REQUIREMENTS.md` in the same commit (fields `v2`, `Plan`, `Evidence`; `done` needs a test or a measurement as evidence) and runs `python tools/req_index.py`. Never edit `doc/REQUIREMENTS-INDEX.md` by hand. A requirement says what the user sees or experiences, not how it is built. New requirements and changes of `Prio`, `Scope` or `Doubt` are decisions of the project owner: an agent proposes them in its report.

## Working in parallel

Several agents may work at the same time only in **separate workspaces**: one git worktree and one branch `wip/<name>` per agent (`python tools/new_workspace.py <name>`). Never change the main checkout or another workspace, and do not merge into `v2-port` yourself; the integrator does. Roles, rules, conflict-prone files and limits: `doc/PARALLEL-WORK.md`. If you were not started in a workspace of your own and other agents may be working, ask before you change files. A prompt for an orchestrator that starts and integrates the agents: `doc/ORCHESTRATOR.md`.

## Tools in this environment

- AHK v2: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` (several versions installed). Scripts always start with `#Requires AutoHotkey v2.0`. **64 bit only** (E0004): 32-bit interpreters are not supported.
- Python 3.13 with `psutil`. Install test dependencies: `pip install -r tests/requirements.txt` (pytest, pytest-timeout, pytest-xdist).
- **Architecture check:** `python tools/arch_check.py` checks `src/**/*.ahk` statically against the rules in `doc/CONVENTIONS.md` section 3. Also runs as `tests/test_architecture.py`. Justified exceptions: comment `; arch-ok: <rule> <justification>` or the `EXCEPTIONS` list in the tool.
- **Requirements index:** `python tools/req_index.py` checks `doc/REQUIREMENTS.md` and writes `doc/REQUIREMENTS-INDEX.md`; `--check` only checks. It fails on a broken format, an evidence path or test that does not exist, a reference to an unknown requirement ID, and (with `--check`) an outdated index. Also runs as `tests/test_requirements.py` (fast tier). VS Code task `Tool: requirements index (req_index.py)`.
- **Long runs on a frozen state:** `python tools/run_suite.py [--with-changes] [--ref <commit>] [--workers N] [-- <pytest arguments>]` creates a worktree (HEAD, HEAD plus the uncommitted changes, or any commit), runs pytest there, writes output, result and run log to `%TEMP%\ahf_runs\<id>\` and removes the worktree. Use it for runs that take minutes, so work can continue in the working tree; start it in the background and read `output.txt`. It limits the load (4 workers, 2 runs at the same time; a `-m stress`/`-m soak` run waits for an idle machine). Files that are neither committed nor untracked-and-not-ignored are missing there on purpose. `--status` lists the last runs.
- **Tests run in parallel by default** (`pytest.ini`: `-n auto --dist loadgroup`). `python -m pytest tests -q` is enough: it runs the **fast tier** (no `slow`, no `foundation`, no `gui`, no `stress`; about 15 s). Slow tests (`--all -m slow`) run at the end of a package that touches timing, supervisor, worker or storage and at the end of a block. The base (IPC, supervisor, diagnosis: `--foundation`) runs when a change touches `src/core/`, `src/supervisor/`, `src/Ahf*.ahk`, `src/debugview/`, `tests/support/` or `tests/integration/helpers/`, and at the end of a block. `--all` runs fast + slow + foundation + gui. `gui` tests open real windows and dialogs: **agents never run them** unless the project owner asks (`doc/TEST-STRATEGY.md` section 6). Serial: `-n 0` (needed to debug one test with `-s`/`--pdb`). `-m stress`/`-m soak` run in one process (measurements must not run alongside other load). New AHK test scripts that may run concurrently need `#SingleInstance Off`, otherwise AHK opens a confirmation dialog.
- Measured values for an AHK v2 process (spike): start ~30 ms, ~14 MB, 0 % CPU idle. Named pipe with wake-up: round trip ~0.3 ms. See `doc/MEASUREMENTS.md`.
- Pitfall: when writing files through shell heredocs, `\\` can collapse to `\` (pipe names!). Write source code with the editor tool and build pipe names from constants.
- **Never start AHK scripts directly; use `python tools/ahkrun.py [--timeout N] script.ahk [args]`.** An unhandled AHK error or a `MsgBox` otherwise opens a dialog that blocks the call forever. `ahkrun.py` passes `/ErrorStdOut=UTF-8` (load errors such as syntax errors go to stderr), catches any dialog that still appears (text and PNG screenshot in `%TEMP%\ahf_dialogs\`, the path is printed), closes it and ends the process. Exit codes: 97 dialog caught, 98 timeout, 99 no interpreter. The pytest runs use the same guard automatically.
- Never pass unknown command-line options (e.g. `--version`) to the AHK interpreter: it takes them for a script name and shows a dialog.
- **Other interpreter:** `python tools/ahkrun.py --interpreter <exe> [--timeout N] script.ahk` runs a script with another interpreter, with the same dialog guard and timeout. Only the v1 interpreter `v1/AutoHotKey/AutoHotFlow.exe` (AutoHotkey_H 1.1.32) is meant for it; it does not understand `/ErrorStdOut=UTF-8`, so `ahkrun.py` passes plain `/ErrorStdOut` to it (verified: with `=UTF-8` it opens a dialog).
- **Golden data of v1** (`tests/golden/`, WI-0036, `doc/TEST-STRATEGY.md` section 7), **frozen since E0035** (regression test of the converter, no new cases against v1; the oracle of the expression language is native AHK v2, WI-0044): `python tools/golden_v1.py [--check] [--group NAME] [--show ID] [--private]` runs the cases in `tests/golden/cases/` with the unchanged v1 code in the v1 interpreter and writes `tests/golden/expected/`; `python tools/golden_corpus.py [--stats|--report]` collects the cases from the parameter values of the example flows. Generation only on purpose (VS Code tasks `Testdata: ...`). `tests/golden/private/` (the owner's own flows) is local only and in `.gitignore`.
- Do not redefine built-in AHK v2 class names (`TimeoutError`, `ValueError`, `OSError`, `TypeError`, `MemberError`, ...). Own error classes carry the prefix `Ahf` (`AhfTimeoutError`).
- `.claude/commands/` is versioned (project commands). `orchestrate.md` starts the orchestrator (`doc/ORCHESTRATOR.md`).

## Looking up AHK help online

The local help file (`C:\Program Files\AutoHotkey\v2\AutoHotkey.chm`) cannot be read, so use the online docs.

- Start page (table of contents): `https://www.autohotkey.com/docs/v2/`
- Function overview (all built-ins, alphabetical): `https://www.autohotkey.com/docs/v2/lib/index.htm`
- Single function/command: `https://www.autohotkey.com/docs/v2/lib/<Name>.htm`, e.g. `lib/StrSplit.htm`
- Language concepts: `https://www.autohotkey.com/docs/v2/<page>.htm`, e.g. `Objects.htm`, `Hotkeys.htm`, `Functions.htm`
- Anchors with `#`, e.g. `lib/Math.htm#Abs`

Procedure:
1. Load the page with WebFetch, with a concrete question in `prompt` (e.g. "syntax and parameters of X").
2. For an unknown name, search `lib/index.htm` first.
3. The docs are for AutoHotkey v2 and apply to the new code. The code under `v1/` uses v1 syntax (`#NoEnv`, `SetBatchLines`, commands without parentheses such as `MsgBox,`). When reading v1 code, watch for the differences.
