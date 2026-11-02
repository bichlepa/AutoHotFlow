# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-11-02. Full texts of findings are in `doc/OPEN-ITEMS.md`; the state of the work is in `work_items/phase3/STATUS.md`.

## Manual checks

- **Manual check 10 (S0006, editing at 100 % and 225 %)** and **manual check 11 (S0007, settings, assistants, help in the three viewers, flow settings, error window).** The gui tests are written and not run (VS Code tasks `Test: ... (gui ...)` and `Start: manual check ...`). Until then REQ-EDT-050/060/070/080/090/120/130/140/200 and REQ-LNG-040 stay `partial`; S0007 is not accepted.
- **Manual check 12 (S0008, written in `doc/MANUAL-CHECKS.md`, 39 steps, VS Code tasks `Start: manual check 12 ...`):** sound, speech, volume, mouse and keys into a test window, screenshot, screen settings read, input block, dialogs of WI-0128 and the Dialog test flow, the demonstration flows (look of the group, Loop tutorial run, element settings dialog F-0211), a shortcut of `Trigger_Shortcut` on the desktop, the S0008 gui tests. Power and session elements are not in the list. S0008 is accepted when you close it.
- **WI-0097 screenshots (REQ-EDT-020):** the look of selection, buttons and drag waits for your acceptance; re-create them with the screenshot tool of the editor if `temp/editor-screenshots/` is gone.
- Not covered by the S0004 record: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German manager texts (`assets/language/manager/de.ini`).

## Decisions

Open:

- **F-0162** drag of 30 elements 26.9 ms vs the 16 ms budget; decide after the feel in the real window.
- **F-0163** a patch during a rename is not written until the next save. **F-0164** drop the `v1Text` marker when an element waiting for its class is patched?
- **WI-0094 trigger activity:** after removals in a patch the flow may become inactive; undo of a sole trigger returns it disabled. The reviewer suggests "active before the patch" or restoring the old state on undo.
- **F-0184** (WI-0113) the error window shows variable values, passwords included, in clear text; the engine keeps the last 5 errors per flow. Confirm, or ask for masking/opt-in.
- **F-0185** text fields are not checked as expressions (`%name%`, `{` give no warning). Confirm.
- **F-0167** the four general v1 help pages exist only as converted Markdown (`v1/Help/en` is gitignored). Where is the original v1 text kept?
- **F-0175** wrong requirement reference (REQ-USE-080 names REQ-USE-070).
- **F-0132** UNC paths are refused for `.ahf` import/export.
- **F-0181** field types no core element uses (for S0008); **F-0182/F-0183** tracker window mode, extend E0076 to the colour dialog?
- **S0007 proposals:** `work_items/phase3/WI-0114-result-s7.md` sections 6 and 7.
- **M-0099** (S0008) the numeric radio defaults of v1 (`default: 1`) become the enum value in v2. Please confirm.

- **S0008, WI-0126 to WI-0131 (2026-11-02):**
  - **Hotkey test flow** (corpus, `Flow 2133155705`) stays in PENDING: decide between real keys with an unassigned-key copy, or mark the Ctrl+F7 part `gui`. The gui tests for real clicks and keys of WI-0126 are not written. F-0192: a blocked input stays blocked when the worker is killed or when Unblock runs in another pool worker.
  - **Script elements (WI-0130):** the children of a script survive a normal end (as v1), a stop kills them; script error texts are English, not `Lang()`; imported v1 scripts are not marked (F-0193).
  - **Set element parameter (WI-0129):** the v1 choice "Type of parameter" is not ported (M-0161); the hotkey parameter is a text field; a failed name regeneration of the target is only logged.
  - **Triggers (WI-0131):** a time missed in standby is not repeated; the hotstring replacement is sent by the trigger host.
  - **Input tests:** `@input` tests send real keys; typing during a verification run can make them fail.

- **WI-0134 demonstration flows:** a demo keeps its ID and wins over a user flow with the same ID (M-0187); `HideDemoFlows` hides only in the manager, the engine still loads them (M-0186); import of a flow with a demo ID is skipped (alternative: import as copy; reviewer recommends skip); group "Demonstration" first as in v1.
- **WI-0135:** the corpus starter, Dialog test and Hotkey test do not run headless (real keys/windows; F-0214): decide on reduced test copies or `gui`. F-0215: package Default has ko 115 and ru 72 of 1,054 keys. F-0216: 8 workers would be about 131 MB (extrapolated), above the E0040 budget of 100 MB; 1 worker + editor is 80 MB.

Decisions the S0008 agents took for you (say so if you want it differently; details in `doc/MIGRATION.md` and the STATUS notes):

- **Paths of destructive file elements** (M-0119, M-0129): empty path, drive root, drive-relative path and (Delete folder, Set attributes/time) the working directory are refused with an error. In v1 an empty path meant the working directory. F-0188 lists the remaining gaps.
- **ActsOnSystem** is true for all file, process, power and clipboard elements, readers included (they appear in the import warning). Readers could get `false`.
- **Kill process** has no guard for AutoHotFlow's own or critical system processes.
- **Sound and speech without waiting** live only in the starting worker (M-0131): Stop sound reaches only that worker. F-0190: the waits of the sound elements have no deadline.
- **Window elements:** Activate waits 2 s and then continues without error (M-0136); control text uses `ControlTextMatchMode` (M-0137); an unknown close method closes.
- **Archives/HTTP:** fixed 10-minute deadline for Download and HTTP request (M-0146); Eject always uses the IOCTL path; Compress replaces an existing archive; Extract overwrites.
- **Other differences:** M-0104 to M-0107 (maths/time), M-0108 to M-0112 (strings: YAML throws, JSON keys sorted), M-0128 (ini empty default), M-0125 (Set attributes with no attribute does nothing), M-0123 (Force option of Shutdown/Reboot was inverted in v1).
- **WI-0081:** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. Unpacked size of an `.ahf` limited to 4 MB.

## To know

- The WebView2 loader hashes (F-0186) come from one nuget.org download; cross-check if you like.
- The pre-commit hook regenerated indexes on a CRLF tree once with other sizes than LF (an agent used `--no-verify` once, WI-0100).
- `recheck.py` cannot take test IDs with `@input`.
- **Stress tests** run when a work item requires them (your permission of 2026-10-17); a stress run no longer opens the manager window (F-0143). The **slow tier** is part of the verification of a state.
- Load flakes in full runs (e.g. `test_worker` busy/shutdown tests, F-0191) are green alone and do not block.
