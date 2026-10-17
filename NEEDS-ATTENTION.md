# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-17 (end of the session).

## Decisions

None open.

## Manual checks

None open.

## To know

- **The product start does not start the manager yet.** Only the tray role starts it ("Show manager"). Decide with block B (WI-0077 to WI-0080) when the start should show the manager.
- **Numbering:** the decision on file dialogs (`FileSelect`/`DirSelect` for UI roles) is E0076. E0075 is the tray decision.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). Last runs: 200 flows, ready after 45 s, largest snapshot 0.6 s (WI-0071); manager with 201 flows filled after 0.54 s (WI-0073).
- **Slow tier:** relevant again (your decision of 2026-10-17). The verification of the last state included it, and it was green.
