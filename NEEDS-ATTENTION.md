# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-15, after the owner's decisions of the same day.

## Decisions

1. **Check the tray menu entry "Beenden" by hand (MANUAL-CHECKS step 7).** Start `src/AutoHotFlow.ahk`, right-click the tray icon: exactly one entry "Beenden". It ends the application like the window button (exit code 0). A double-click does nothing. Tell the orchestrator whether this is right.

Other decisions of 2026-10-15 are in `doc/DECISIONS.md` (E0046 to E0051).

## To know

- **Lost log line under load (F-0088 closed 2026-10-15, F-0089 open).** F-0088 is fixed and verified (`doc/CLOSED-ITEMS.md`). F-0089 (three fault tests that fail only under load) is still open and not analysed.
- **Integration of `wip/requirements`** was done on 2026-10-15 (19 commits, rebased, index regenerated).
