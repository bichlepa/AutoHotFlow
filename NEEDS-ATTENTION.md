# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-15, after the owner's decisions of the same day.

## Decisions

1. **Manual check of the tray icon (E0046 as corrected, F-0064).** After the correction is integrated: start `src/AutoHotFlow.ahk` by hand (VS Code task `Start:`). Only the manager shows a tray icon; the debug window and the other roles show none, and test runs show none. Tell the orchestrator whether this is right; F-0064 closes on your answer.

2. **Try the AHF process tool (`tools/ahf_processes.py`, VS Code task `Tool: AHF processes`).** It lists the running AHF processes with start time, running time and window state, and offers "Bring to front" and "End process". Only the list logic is tested; the window focus and the buttons are not. Tell the orchestrator what does not work.

Other decisions of 2026-10-15 are in `doc/DECISIONS.md` (E0046 to E0051).

## To know

- **Lost log line under load (F-0088 closed 2026-10-15, F-0089 open).** F-0088 is fixed and verified (`doc/CLOSED-ITEMS.md`). F-0089 (three fault tests that fail only under load) is still open and not analysed.
- **Integration of `wip/requirements`** was done on 2026-10-15 (19 commits, rebased, index regenerated).
