# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-20.

## Decisions

- **Batch order (WI-0089):** inside one 33 ms batch of element states the entries are in order of the first change, so an instant element can appear after its neighbour; a fast repeating failing element shows only its last state. Accept, or send every change in order inside the batch?
- **Latency with 300 changing elements (F-0156, REQ-PRF-060):** p95 68.8 ms, median 43.8 ms (MS-0050); the loop of three elements reaches p95 46 ms. Options: measure the batch interval and the state path first (recommended), or a render process. Not urgent.
- **Tray "Close" (F-0159):** the table of REQ-EDT-230 says a question about unsaved changes, REQ-EDT-100 says no question. Which one holds?
- **Language files (F-0158):** `assets/language/basic/de.ini`, `ko.ini`, `ru.ini` are UTF-16 but read as UTF-8, so the German text of the editor probably falls back to English. Fix by converting the files (recommended) or by reading both encodings?
- **Look of the editor (E0088):** loop as one object, square corners for loops and actions, icons faded and filling the element are done; you accept the look in manual check 9, step 3 (screenshots in `temp/look2-screenshots/` of the main checkout).

(R0002: decided on 2026-10-19, E0090. Time of the fast tier: E0089. 4K rebuild F-0151: accepted by you on 2026-10-20.)

## Manual checks

- **Manual check 9 (S0005, editor)** in `doc/MANUAL-CHECKS.md`: 25 steps, 3 VS Code tasks (the `gui` tests for the window, real mouse input and the tray icon, and the measurement of the frame time with a window at 1920x1080 and 3840x2160). At 100 % and 225 %, and between two screens if you have them. Do not use the PC while the tray and mouse tests run. Result of the agent part: `work_items/phase3/WI-0092-result-s5.md`. S0005 is accepted when you close this check.
- The manual checks of S0004 passed on 2026-10-19. Not covered by that record: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German manager texts (`assets/language/manager/de.ini`).

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
