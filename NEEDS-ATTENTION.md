# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-17 (end of the session).

## Decisions

- **Log bursts (F-0116, WI-0080).** A burst of 5000 log lines reached the manager as 1991 (the topic `log` drops lines, PROTOCOL 4.6). Options: (a) keep the drop; (b) the log window reads the file again after a burst. Recommendation: (b).
- **Instance count in the tree (WI-0074, F-0117).** REQ-MGR-010 asks for the number of running instances; the manager snapshot does not carry it. Options: (a) extend the protocol (snapshot field); (b) drop it from REQ-MGR-010. 
- **Missing packages of non-trigger elements (WI-0074, F-0120).** They are not marked in the tree. Say if that is wanted for S0004 or later.
- **Source group of the log filter (WI-0080).** "App, flow, thread" is built as the v1 level letters a, f, t, only a stand-in. Say if you meant something else (for example the sender or the source name).
- **Time stamps of the log tail (WI-0080).** The local stamp is converted with the current UTC offset; entries from before a DST change are up to 1 hour off (the window itself is not affected). A fix is about 10 lines (store UTC). Recommendation: leave it, as documented.

## Manual checks

- **Manager tree (WI-0074):** context menus, drag and drop onto a category, Ctrl-click multi-selection (shows the focused item only, F-0119), ask dialogs (delete, unknown state, limit), trigger-not-available notice, state marks. Only the window tests ran (they now include drag and drop); the rest was never seen on screen. Review the German texts too.
- **Log window (WI-0080):** never shown by an agent (only the class load and the window tests run). Check it with WI-0082 or earlier: open it, filters, a flood of lines, DPI. Review the German texts in `assets/language/manager/de.ini`.

## To know

- **The product start does not start the manager yet.** Only the tray role starts it ("Show manager"). Decide with block B (WI-0077 to WI-0080) when the start should show the manager.
- **Numbering:** the decision on file dialogs (`FileSelect`/`DirSelect` for UI roles) is E0076. E0075 is the tray decision.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). Last runs: 200 flows, ready after 45 s, largest snapshot 0.6 s (WI-0071); manager with 201 flows filled after 0.54 s (WI-0073).
- **Slow tier:** relevant again (your decision of 2026-10-17). The verification of the last state included it, and it was green.
