# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-21 (S0008 detailed).

## Decisions

Open (full text in `doc/OPEN-ITEMS.md`): **F-0162** (drag of 30 elements 25 ms vs 16 ms budget; decide after the feel in the real window), **F-0163** (a patch during a rename is not written until the next save), **WI-0094 trigger activity** (after removals in a patch the flow may become inactive; undo of a sole trigger returns it disabled; the reviewer suggests "active before the patch" or restoring the old state on undo; see the WI-0094 commits), **WI-0113 error window** (it shows the values of instance, thread and loop variables of the failed branch in clear text, passwords an element put in a variable included; the engine keeps the last 5 errors per flow, even with the notice switched off; confirm or ask for masking/opt-in), **F-0167** (the four general v1 help pages exist in the repository only as converted Markdown; `v1/Help/en` is gitignored; decide where the original v1 text is kept), **F-0164** (drop the `v1Text` marker when an element waiting for its class is patched?). Decided on 2026-10-21 while S0008 was detailed: E0102 to E0105 (no element converter, REQ-MNT-040 deleted; the seam `SystemOps`; AutoHotkey scripts exchange variables as in v1; three read-only demo flows without the Update checker). Decided on 2026-10-20 while S0006 and S0007 were detailed: E0091 to E0100 (clipboard, new triggers, crashed editor, rectangle selection, S0007 detailed with S0006, expression check, help content, help window, three help viewers, help in Markdown). Answered on 2026-10-20 before: the look of the editor is accepted (E0088), the batch order and F-0156 are postponed (F-0161, F-0156), REQ-EDT-230 follows REQ-EDT-100 (F-0159), the language files are re-saved as UTF-8 (F-0158). 4K rebuild F-0151 accepted. (R0002: E0090. Time of the fast tier: E0089.)

## Manual checks

- **WI-0097 screenshots (REQ-EDT-020):** the look of selection, buttons and drag waits for your acceptance; re-create them with the screenshot tool of the editor if `temp/editor-screenshots/` is gone.

- **Manual check 9 (S0005):** done on 2026-10-20 (record in `doc/MANUAL-CHECKS.md`). Step 25 (4K window measurement) was not run: you have no 4K screen. Nothing waits.
- The manual checks of S0004 passed on 2026-10-19. Not covered by that record: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German manager texts (`assets/language/manager/de.ini`).

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.

## Waiting for you (2026-10-22)

- **Manual checks:** 10 (S0006, editing at 100 % and 225 %) and 11 (S0007, settings, assistants, help in the three viewers, flow settings, error window). The gui tests are written and not run (VS Code tasks `Test: ... (gui ...)` and `Start: manual check ...`). Until then REQ-EDT-050/060/070/080/090, 120, 130, 140, 200 and REQ-LNG-040 stay `partial`.
- **Decisions:** F-0162 (drag of 30 elements 26.9 ms vs 16 ms), F-0184 (the error window shows variable values, passwords included, in clear text), F-0185 (text fields are not checked as expressions, confirm), F-0175 (wrong requirement reference), F-0163/F-0164/WI-0094 (see above), F-0167 (original v1 help text), F-0182/F-0183 (tracker mode, extend E0076 to the colour dialog?), F-0181 (field types no core element uses, for S0008), the S0007 proposals in `work_items/phase3/WI-0114-result-s7.md` sections 6 and 7.
- **Facts:** the WebView2 loader hashes (F-0186) come from one nuget.org download, cross-check if you like. `tools/hooks` pre-commit hook regenerated indexes on a CRLF tree once with other sizes than LF (an agent worked around it with --no-verify once, WI-0100). `recheck.py` cannot take test IDs with `@input`.
