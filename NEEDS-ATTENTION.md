# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-17 (WI-0075, WI-0076, WI-0081 integrated, dialog text fix integrated, WI-0077 in fix round).

## Decisions

Nothing waits for a decision now. (F-0116 decided: keep the drop, E0082; test adjusted and closed.)

## Manual checks

- **Manager tree (WI-0074):** context menus, drag and drop onto a category, Ctrl-click multi-selection (shows the focused item only, F-0119), ask dialogs (delete, unknown state, limit), trigger-not-available notice, state marks. Only the window tests ran (they now include drag and drop); the rest was never seen on screen. Review the German texts too.
- **Notices (WI-0075):** the real tray balloon (TrayTip) was never seen on a desktop; tree mark and limit value in a real window; the notice list was checked once by a GUI test. Review the German texts (`assets/language/manager/de.ini`). The notice for a storage error has no test (F-0125).
- **`.ahf` export and import (WI-0081):** MANUAL-CHECKS part E (steps 34 to 43): export, import, drag and drop, the warning with the list of acting elements, name conflict. Whether v1 or 7-Zip can open a `.ahf` written by v2 (F-0129): please try once. The question dialog texts must now be fully visible at 100 % and 225 % (fix F-0128; step 33).
- **Log window (WI-0080):** never shown by an agent (only the class load and the window tests run). Check it with WI-0082 or earlier: open it, filters, a flood of lines, DPI. Review the German texts in `assets/language/manager/de.ini`.

## To know

- **Owner decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.

- **The product start does not start the manager yet.** Only the tray role starts it ("Show manager"). Decide with block B (WI-0077 to WI-0080) when the start should show the manager.
- **Numbering:** the decision on file dialogs (`FileSelect`/`DirSelect` for UI roles) is E0076. E0075 is the tray decision.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). Last runs: 200 flows, ready after 45 s, largest snapshot 0.6 s (WI-0071); manager with 201 flows filled after 0.54 s (WI-0073).
- **Slow tier:** relevant again (your decision of 2026-10-17). The verification of the last state included it, and it was green.
