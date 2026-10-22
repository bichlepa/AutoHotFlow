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

## S0008 so far (2026-10-23): decisions and checks for you

Done: WI-0116 to WI-0125 (schema check against v1, `SystemOps` seam, maths/time/script, strings/lists, files and folders I and II with the file loop and ini, programs/clipboard/power, sound/speech, windows/controls, archives/drives/internet). Details per work item: `work_items/phase3/STATUS.md`. Decisions the agents took (say so if you want it differently):

- **M-0099** numeric radio defaults of v1 (`default: 1`) become the enum value in v2. Please confirm.
- **Paths of destructive file elements** (M-0119, M-0129): an empty path, a drive root, a drive-relative path and (Delete folder, Set attributes/time) the flow's working directory are refused with an error. In v1 an empty path meant the working directory. F-0188 lists the remaining gaps of these guards.
- **ActsOnSystem** is true for all file, process, power and clipboard elements, readers included (they appear in the import warning). Reader elements could get `false`.
- **Kill process** has no guard for AutoHotFlow's own processes or critical system processes.
- **Sound and speech without waiting** live only in the worker that started them (M-0131): Stop sound reaches only that worker, and an idle worker that ends cuts the sound. Alternative: a shared player process. F-0190: the waits of the sound elements have no deadline.
- **Window elements:** Activate waits 2 s and then continues without an error (M-0136); control text uses `ControlTextMatchMode` (M-0137, old flows may match differently); an unknown close method closes.
- **Archives/HTTP:** fixed deadline of 10 minutes for Download and HTTP request instead of a parameter (M-0146); Eject always uses the IOCTL path (the USB library of v1 is not ported); Compress replaces an existing archive; Extract overwrites existing files.
- **Other deliberate differences:** M-0104 to M-0107 (maths/time), M-0108 to M-0112 (strings: YAML throws, JSON keys sorted, new text mode Plain/RegEx), M-0128 (ini read with an empty default), M-0125 (Set attributes with no attribute chosen does nothing), M-0123 (Force option name of Shutdown/Reboot was inverted in v1). The v1 originals are in the MIGRATION entries.
- **Manual check 12 (planned for WI-0135)** will cover what no agent can check: real shutdown/lock/hibernate, clipboard, sound, speech, eject/lock of a drive, Minimize all windows, DPI of other monitors, the recycle bin, a real shortcut.

## Waiting for you (2026-10-22)

- **Manual checks:** 10 (S0006, editing at 100 % and 225 %) and 11 (S0007, settings, assistants, help in the three viewers, flow settings, error window). The gui tests are written and not run (VS Code tasks `Test: ... (gui ...)` and `Start: manual check ...`). Until then REQ-EDT-050/060/070/080/090, 120, 130, 140, 200 and REQ-LNG-040 stay `partial`.
- **Decisions:** F-0162 (drag of 30 elements 26.9 ms vs 16 ms), F-0184 (the error window shows variable values, passwords included, in clear text), F-0185 (text fields are not checked as expressions, confirm), F-0175 (wrong requirement reference), F-0163/F-0164/WI-0094 (see above), F-0167 (original v1 help text), F-0182/F-0183 (tracker mode, extend E0076 to the colour dialog?), F-0181 (field types no core element uses, for S0008), the S0007 proposals in `work_items/phase3/WI-0114-result-s7.md` sections 6 and 7.
- **Facts:** the WebView2 loader hashes (F-0186) come from one nuget.org download, cross-check if you like. `tools/hooks` pre-commit hook regenerated indexes on a CRLF tree once with other sizes than LF (an agent worked around it with --no-verify once, WI-0100). `recheck.py` cannot take test IDs with `@input`.
