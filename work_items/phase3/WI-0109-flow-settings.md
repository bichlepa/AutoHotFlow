# WI-0109 Flow settings dialog and the switch of the error notices per flow

Size: M · Depends on: WI-0096, WI-0102 · Blocks: WI-0114

## Goal

The user sets, per flow: the execution policy, the working directory, the type mode, the limits of the runaway guard and the notices of unhandled errors. A button shows the log of the flow. Requirements: REQ-EDT-140, REQ-EXE-050 (per flow), REQ-EXE-130 (per flow), REQ-EXE-170 (per flow), REQ-VAR-100 (the type mode), REQ-USE-070 (the switch per flow).

## Read first

`AGENTS.md`; `doc/PROTOCOL.md` 4.2 (runaway guard, settings), 4.7 (the switch per flow); `doc/ARCHITECTURE.md` 7 (`strictTypes`); `doc/DECISIONS.md` E0034, E0062; WI-0080 (the log display of the manager); WI-0105 (the pattern of model and window); v1: `v1/Source_Editor/User Interface/Flow settings.ahk`.

## Tasks

1. **Docs first:** the keys of `flowSettings` (`ExecutionPolicy`, `DefaultWorkingDir`, `WorkingDir`, `strictTypes`, the three limits, the new switch of the notices), and when the engine reads each of them.
2. **The dialog** (model and window):
   - Policy: default, parallel, skip, wait, stop.
   - Working directory: the global one or its own (a folder dialog).
   - Type mode: strict or compatible, with a short explanation. Switching a migrated flow to strict gives a warning.
   - The three limits: default, 0, or a number.
   - The switch of the notices.
   - "Show log": the manager's log window filtered to this flow (a command to the manager, for example `cmd.manager.showLog {flowId}`; if the log display of WI-0080 cannot filter yet, add the filter).
3. **OK** sends one `flow.settings` patch (one undo step).
4. **Engine:** policy, working directory, type mode, limits and the switch take effect as their requirements say (from the next start or the next step). The switch per flow is applied to the notices of the engine.
5. **Tests:** headless (model and engine effects); a gui test (owner).

## Acceptance criteria

- The tests of task 5 are green. PROTOCOL is updated. REQ-EDT-140, REQ-EXE-050, REQ-EXE-130, REQ-EXE-170, REQ-VAR-100 and REQ-USE-070 are updated.

## Not part of this

The global settings (S0004, done).

## Refinement from WI-0104 (proposal, not decided)

Written by the acceptance of S0006 (WI-0104, E0095). The project owner decides whether this stands; the package may refine it again and says so in its result.

- The flow settings are a `flow.settings` patch, which is an undo step (unlike the view, which is marked `view: true`). Check that a settings change is one step and that a view change still is none.
- The menu entry `settings` is disabled in `EditorMenus.BarSpec` (allowed false) until this package; enable it there and in `_Act`, as WI-0106 does for `edit`.
