# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-17 (end of the session).

## Decisions

- **Context menus of the manager (needed before WI-0074).** A context menu stops the threads of the process while it is open (measured for the tray, `doc/MEASUREMENTS.md`, WI-0072). The manager's tree menus (WI-0074) have the same problem. Options: (a) accept it and document the limit; (b) give the menus their own small process, as the tray (E0075). Recommendation: (b).

## Manual checks

- **Manual check 3, rest (REQ-USE-090):** the dialog windows were moved to the shared layout (`core/GuiLayout.ahk`, WI-0069). The check at 125 % and 150 %, a second monitor, and the DPI change of an open window are still open. The manager window at 225 % and the minimize-then-hide case (WI-0073) are not checked either.
- **Skip of the hotkey input tests on a locked PC (WI-0064):** the skip is built (session check plus `LogonUI.exe`). It has not yet run on a real lock screen. Check: lock the PC, run the `@input` tests; they must be skipped with the reason "the input desktop is not usable".

## To know

- **The product start does not start the manager yet.** Only the tray role starts it ("Show manager"). Decide with block B (WI-0077 to WI-0080) when the start should show the manager.
- **Numbering:** the decision on file dialogs (`FileSelect`/`DirSelect` for UI roles) is E0076. E0075 is the tray decision.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). Last runs: 200 flows, ready after 45 s, largest snapshot 0.6 s (WI-0071); manager with 201 flows filled after 0.54 s (WI-0073).
- **Slow tier:** relevant again (your decision of 2026-10-17). The verification of the last state included it, and it was green.
