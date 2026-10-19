# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-19 (documentation review: the manual checks of S0004 are done and removed).

## Decisions

Nothing waits for a decision now. (R0002: decided on 2026-10-19, E0090: caches in the editor process. Time of the fast tier: E0089.)

## Manual checks

Nothing waits. The manual checks of S0004 (manager parts A to E, start with Windows and UAC, settings dialog) passed on 2026-10-19; the record is in `doc/MANUAL-CHECKS.md`. Not covered by that record, in case you want to look once: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German texts of the manager (`assets/language/manager/de.ini`), which no agent has reviewed.

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **S0005:** you accept the look of the renderer yourself (E0088, WI-0085).
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
