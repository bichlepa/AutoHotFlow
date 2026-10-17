# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-17 (end of the session).

## Decisions

- **Log burst (F-0116): your decision E0078 rests on a wrong premise.** The bug hunter measured: the lines are not lost on the topic `log`. The hub drops them before storage ("log lines dropped, send queue to storage was full", soft limit 800 per queue), storage writes about 1900 of 5000 lines to the files, and the manager shows exactly those. Re-reading `Log.txt` would show the same lines. Options: (a) keep the drop (it protects the hub from a flood) and change the test to "the model equals what storage wrote"; (b) raise the intake of storage (changes the drop policy of PROTOCOL 4.6, F-0016, F-0066). Recommendation: (a). The other three decisions (E0079 to E0081) are done on the hunter's branch, in review.

## Manual checks

- **Manager tree (WI-0074):** context menus, drag and drop onto a category, Ctrl-click multi-selection (shows the focused item only, F-0119), ask dialogs (delete, unknown state, limit), trigger-not-available notice, state marks. Only the window tests ran (they now include drag and drop); the rest was never seen on screen. Review the German texts too.
- **Log window (WI-0080):** never shown by an agent (only the class load and the window tests run). Check it with WI-0082 or earlier: open it, filters, a flood of lines, DPI. Review the German texts in `assets/language/manager/de.ini`.

## To know

- **The product start does not start the manager yet.** Only the tray role starts it ("Show manager"). Decide with block B (WI-0077 to WI-0080) when the start should show the manager.
- **Numbering:** the decision on file dialogs (`FileSelect`/`DirSelect` for UI roles) is E0076. E0075 is the tray decision.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). Last runs: 200 flows, ready after 45 s, largest snapshot 0.6 s (WI-0071); manager with 201 flows filled after 0.54 s (WI-0073).
- **Slow tier:** relevant again (your decision of 2026-10-17). The verification of the last state included it, and it was green.
