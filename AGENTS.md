# AGENTS.md

## Language

**The repository is English only**: code, comments, documentation, log texts, commit messages, VS Code task labels and issue/PR texts. This keeps the project open for contributors worldwide.

## What this is

AutoHotFlow (AHF) is being ported from AutoHotkey v1 (AutoHotkey_H with `AhkThread`) to **AutoHotkey v2**. The architecture is rebuilt so that the old deadlocks and race conditions cannot occur by design: **several processes that exchange messages, no shared memory, no global lock**.

## Current state

- Branch `v2-port` (the port). `master` is the working v1.
- Phase 0 (inventory) and phase 1 (design) are done and approved.
- **Phase 2 (walking skeleton) is complete.** Phase 2b (hardening) is complete, and the fix block WI-30 to WI-35 is complete with a green acceptance run (WI-35 cycle 1, code state `2f2e6e5`).
- Not built yet: trigger host (E6, early in phase 3), editor, real manager, real elements. The GUI of the stub has not been checked by hand.
- **Phase 3 has not started and needs the project owner's approval.** Its plan is being drafted with the project owner.
- Open findings: `doc/OPEN-ITEMS.md`. Decisions: `doc/DECISIONS.md`. Work-package history: `doc/HISTORY.md`. Full work-item history before the cleanup: git tag `v2-phase2-final` (`git show v2-phase2-final:work_items/STATUS.md`).
- Test timing: `tests/support/timing.py` (`scaled()`; see `doc/TEST-STRATEGY.md`).

## Entry points

- Product: `src/AutoHotFlow.ahk` (includes `src/AhfBoot.ahk`).
- Test roles (`echo`, `crasher`, `hanger`, `slow_shutdown`) exist only in the test entry point `tests/integration/helpers/AutoHotFlowTest.ahk` with `--test-roles`. Nothing in `src/` includes anything from `tests/`.
- Layout of the v2 code: `doc/ARCHITECTURE.md`, section 8.
- The v1 code lives unchanged in `v1/` (temporary, reference only, **do not change**).

## Decisions (binding, details in `doc/ARCHITECTURE.md`)

- Processes instead of threads: `supervisor` (hub), `storage`, `engine`, `triggerhost`, `manager`, one `editor` per open flow, a `worker` pool.
- IPC over named pipes (frame: length prefix + JSON, wake-up via `PostMessage`), star topology through the supervisor.
- Drawing happens in the editor process behind the `Renderer` interface (separable later).
- Elements run `inline` (engine), `worker` (own process) or `trigger` (trigger host). Dialogs never run in the engine.
- Old flows (`.json`) and variables (`.ahfvd`/`.ahfvar`) must load unchanged. The Chrome package is dropped.
- Tests: pytest as the driver (e2e, fault injection, stress) plus small AHK unit tests.

## Folders

| Path | Purpose |
|---|---|
| `doc/` | Lasting documentation (architecture, protocol, element API v2, test strategy, conventions, migration, how-to AHK v2) |
| `work_items/` | Temporary working papers of phase 3 (plans, work packages). Delete after the port. Earlier work items: tag `v2-phase2-final`. |
| `v1/` | Temporary v1 reference. Removed after the port. |
| `src/`, `tests/`, `tools/`, `assets/` | v2 code (layout: `doc/ARCHITECTURE.md` section 8) |

## Rules for changes

1. Before a task read: this file, `doc/ARCHITECTURE.md` (sections 1 to 6), `doc/CONVENTIONS.md`, then the document for your own task. For AHK v2 code also `doc/HOW-TO.md`.
2. No shared mutable state, only messages. Every datum has exactly one owner.
3. No blocking call on the message path (`MsgBox`, file I/O, `RunWait`, `WinWait` without timeout). Every request has a timeout.
4. Do not change anything in `v1/`. Deliberate deviations from v1 behavior go into `doc/MIGRATION.md`.
5. New message types go into `doc/PROTOCOL.md`. Whoever changes an interface updates that document in the same commit.
6. Distinguish **verified** (read or tested), **assumed** and **not checked**. Do not claim anything about code you have not read.
7. Small commits, one change per commit. The commit message explains the why.
8. Element code must never crash the engine: every call under `try/catch`, errors are reported as result `exception`.
9. Difficulties and own mistakes in the AHK v2 implementation go into `doc/HOW-TO.md`: what was hard, what was wrong, what works (format in the file). Each entry carries a status (verified / assumed / not checked). This is not a bug tracker. Good: bugs that could easily come back. Bad: past bugs in a finished module.
10. **VS Code tasks for the project owner:** every call the project owner may want to run by hand (tests, starting the app or a role, tools, manual checks from a guide) gets a task in `.vscode/tasks.json`. Whoever adds or changes such a call (new option, new role, new tool, new test group) updates the task in the same commit. Labels are in English with a prefix (`Test:`, `Start:`, `Tool:`, `Debug:`, `Testdata:`, `Setup:`). Exception to "never start AHK scripts directly": the `Start:` tasks start `AutoHotkey64.exe` directly, without `ahkrun.py` and without timeout, because the owner operates the app (a dialog then blocks until closed). Agents still use `ahkrun.py`.

## Tools in this environment

- AHK v2: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` (several versions installed). Scripts always start with `#Requires AutoHotkey v2.0`. **64 bit only** (E4): 32-bit interpreters are not supported.
- Python 3.13 with `psutil`. Install test dependencies: `pip install -r tests/requirements.txt` (pytest, pytest-timeout, pytest-xdist).
- **Architecture check:** `python tools/arch_check.py` checks `src/**/*.ahk` statically against the rules in `doc/CONVENTIONS.md` section 3. Also runs as `tests/test_architecture.py`. Justified exceptions: comment `; arch-ok: <rule> <justification>` or the `EXCEPTIONS` list in the tool.
- **Tests run in parallel by default** (`pytest.ini`: `-n auto --dist loadgroup`). `python -m pytest tests -q` is enough. Serial: `-n 0` (needed to debug one test with `-s`/`--pdb`). `-m stress`/`-m soak` run in one process (measurements must not run alongside other load). New AHK test scripts that may run concurrently need `#SingleInstance Off`, otherwise AHK opens a confirmation dialog.
- Measured values for an AHK v2 process (spike): start ~30 ms, ~14 MB, 0 % CPU idle. Named pipe with wake-up: round trip ~0.3 ms. See `doc/MEASUREMENTS.md`.
- Pitfall: when writing files through shell heredocs, `\\` can collapse to `\` (pipe names!). Write source code with the editor tool and build pipe names from constants.
- **Never start AHK scripts directly; use `python tools/ahkrun.py [--timeout N] script.ahk [args]`.** An unhandled AHK error or a `MsgBox` otherwise opens a dialog that blocks the call forever. `ahkrun.py` passes `/ErrorStdOut=UTF-8` (load errors such as syntax errors go to stderr), catches any dialog that still appears (text and PNG screenshot in `%TEMP%\ahf_dialogs\`, the path is printed), closes it and ends the process. Exit codes: 97 dialog caught, 98 timeout, 99 no interpreter. The pytest runs use the same guard automatically.
- Never pass unknown command-line options (e.g. `--version`) to the AHK interpreter: it takes them for a script name and shows a dialog.
- Do not redefine built-in AHK v2 class names (`TimeoutError`, `ValueError`, `OSError`, `TypeError`, `MemberError`, ...). Own error classes carry the prefix `Ahf` (`AhfTimeoutError`).
- `.claude/commands/*` (local, not versioned) still refer to the v1 structure.

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
