# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-20 (S0006 and S0007 detailed).

## Decisions

Open (full text in `doc/OPEN-ITEMS.md`): **F-0162** (drag of 30 elements 25 ms vs 16 ms budget; decide after the feel in the real window), **F-0163** (a patch during a rename is not written until the next save), **WI-0094 trigger activity** (after removals in a patch the flow may become inactive; undo of a sole trigger returns it disabled; the reviewer suggests "active before the patch" or restoring the old state on undo; see the WI-0094 commits), **F-0164** (drop the `v1Text` marker when an element waiting for its class is patched?). Decided on 2026-10-20 while S0006 and S0007 were detailed: E0091 to E0100 (clipboard, new triggers, crashed editor, rectangle selection, S0007 detailed with S0006, expression check, help content, help window, three help viewers, help in Markdown). Answered on 2026-10-20 before: the look of the editor is accepted (E0088), the batch order and F-0156 are postponed (F-0161, F-0156), REQ-EDT-230 follows REQ-EDT-100 (F-0159), the language files are re-saved as UTF-8 (F-0158). 4K rebuild F-0151 accepted. (R0002: E0090. Time of the fast tier: E0089.)

## Manual checks

- **WI-0097 screenshots (REQ-EDT-020):** the look of selection, buttons and drag waits for your acceptance; re-create them with the screenshot tool of the editor if `temp/editor-screenshots/` is gone.

- **Manual check 9 (S0005):** done on 2026-10-20 (record in `doc/MANUAL-CHECKS.md`). Step 25 (4K window measurement) was not run: you have no 4K screen. Nothing waits.
- The manual checks of S0004 passed on 2026-10-19. Not covered by that record: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German manager texts (`assets/language/manager/de.ini`).

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
