# WI-0076 Import from v1: flows and variables, report

Size: L · Depends on: WI-0070, WI-0074 · Blocks: WI-0077, WI-0081, the manual check after block A

## Goal

The user imports the flows and the global and static variables of v1 into v2 through the manager, by the rules of E0068, and sees a report with the places that need a fix (MIGRATION IDs). The v1 folder is only read. Afterwards the manager offers to remove the autostart entry of v1. At the end of block A this package writes the manual check of the manager. Requirements: REQ-MIG-060, REQ-SEC-060 (imported flows disabled), REQ-MIG-040 (the report in the manager).

## Read first

As WI-0074, plus E0021, E0027, E0035, E0058, E0068 in `doc/DECISIONS.md`; REQ-MIG-010 to REQ-MIG-070; `doc/MIGRATION.md` (how markers look); `tools/migration_report.py` (what the report lists today, in Python); PROTOCOL 4.6 (variables); `src/storage/VarFiles.ahk`; the v1 data folder layout (README S0004 findings); v1 autostart (read in `v1/Source_Manager/User Interface/Global_Settings.ahk` where the shortcut is made).

## Tasks

1. **Docs first:** PROTOCOL (storage reads a chosen folder outside the data folder: list the flow files of `Saved Flows/` without `demo flows/`, read a file, list and read the variables; the path comes from the user's dialog and is checked; never a write there), engine command for the import (`cmd.import.v1` or a sequence of `cmd.flow.create` with a definition plus a variable command; choose; the variables go through the engine, which owns them), the report format; MIGRATION if a rule differs from v1.
2. **Flows:** every flow of `Saved Flows/` whose ID v2 does not have: created with its ID and its definition (WI-0070: converted, marked, disabled). An existing ID: skipped and listed, or imported as a copy if the user chose it (new ID, the name gets a number). A file that cannot be parsed: listed, the others go on.
3. **Variables:** global ones that v2 does not have are taken over; an existing one keeps its v2 value and is listed. Static ones of every imported flow are taken over (for a copy under the new ID).
4. **Report:** per flow the MIGRATION places (computed by the engine from the markers), the skipped flows and variables, the errors. Shown in the manager (a window that can be copied as text) and written to the log.
5. **Autostart of v1:** after the import the manager asks whether to remove the autostart shortcut of v1 (preselection "no"); "yes" deletes exactly that shortcut through storage, after checking that it points to v1.
6. **Manager:** "Import from v1" with a folder dialog (default `%APPDATA%\AutoHotFlow`), the progress, the report.
7. **Tests:** e2e with a copy of `tests/data/flows/v1_examples/` and v1 variable files laid out as a v1 data folder: all flows created and disabled, an existing ID skipped, the copy option, variables with a conflict, the demo flows skipped, a broken file listed; the source folder unchanged (hash before and after). The autostart removal with a test startup folder (never the real one). Locally also with `tests/golden/private/` (E0027, not in the repository).
8. **Manual check after block A** in `doc/MANUAL-CHECKS.md` with VS Code tasks (rule 10): the import of a copy of the owner's v1 data folder, the tree and the operations, the questions of E0056 and E0063, drag and drop, the notices, the tray icon after a killed manager, the manager at 100 % and 225 % (the rest of manual check 3). Section 1 (stub) is replaced.

## Acceptance criteria

- The tests of task 7 are green, serial and parallel; the manual check is written and its tasks exist.
- REQ-MIG-060 has its evidence.

## Not part of this

The settings of v1 (WI-0077 adds them to the import); `.ahf` files (WI-0081).
