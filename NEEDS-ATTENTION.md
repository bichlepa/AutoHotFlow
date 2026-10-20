# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-20.

## Decisions

- **Look of the editor (E0088, WI-0085):** your feedback of 2026-10-20 is being worked in (loop drawn as one object without seams, icons faded in the background like in v1, square corners for loops and actions). New screenshots will be in `temp/look1-screenshots/` of the main checkout; accept the look or say what to change.

(R0002: decided on 2026-10-19, E0090. Time of the fast tier: E0089. 4K rebuild F-0151: accepted by you on 2026-10-20.)

## Manual checks

Nothing waits. The manual checks of S0004 (manager parts A to E, start with Windows and UAC, settings dialog) passed on 2026-10-19; the record is in `doc/MANUAL-CHECKS.md`. Not covered by that record, in case you want to look once: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German texts of the manager (`assets/language/manager/de.ini`), which no agent has reviewed.

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **S0005:** you accept the look of the renderer yourself (E0088, WI-0085). The window test of the editor (`tests/fault/test_editor_window.py`, VS Code task) and the window variant of the latency measurement (REQ-PRF-060) are GUI runs for you.
- **Open design question (WI-0089):** inside one 33 ms batch of element states the entries are in order of the first change, so an instant element can come after its neighbour; also a fast repeating failing element shows only its last state. Say if you want every change in order inside the batch.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
