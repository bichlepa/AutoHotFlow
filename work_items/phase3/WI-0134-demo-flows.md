# WI-0134 Demonstration flows (E0105)

Size: M · Depends on: WI-0119, WI-0122, WI-0124 (the elements of the demos) · Blocks: WI-0135

## Goal

AutoHotFlow ships three demonstration flows of v1 (Loop tutorial, Pet guesser, Joke teller) in the category "Demonstration". They are read only: they cannot be renamed, moved, deleted or changed; the editor shows them read only and points to "Duplicate"; they are disabled until the user enables them; the setting "Hide demonstration flows" hides them. Requirements: REQ-MGR-060, REQ-SEC-050 (nothing contacts a server by itself).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0105; `doc/ARCHITECTURE.md` 4 (data ownership), 7 (loading v1 flows), 8; `doc/PROTOCOL.md` 4.2 (flow commands, `cmd.flow.patch`), 4.8 (manager), 4.11 (editor); `src/core/SettingsModel.ahk` (`HideDemoFlows` is skipped by the v1 import until now); the manager's flow list and category code (WI-0071, WI-0074); v1: `Saved Flows/demo flows/`, `Source_Common/Flows/Manage Flows.ahk`, `Source_Manager/User Interface/Manager GUI.ahk` (the category `demo`), `Source_Common/Flows/Flow actions.ahk` (the warning when a demo is opened).

## Tasks

1. **Docs first:** ARCHITECTURE 4 and 8 (where the demos live and who owns them), PROTOCOL (the mark `demo` in the flow list and the snapshot, the refusal code of a change), MIGRATION (the Update checker is left out; demos are read only also in the editor).
2. **Files:** the three flows in `assets/demo_flows/`, loaded as v1 flows (E0021); the fixes they need are MIGRATION places in the flow, as for every loaded v1 flow. Check each runs in v2 (the Joke teller needs the network: its test uses the local server of WI-0122 on a copy).
3. **Engine and storage:** the engine loads them with the mark `demo` from the program folder; their trigger states live in the data folder as for every flow, and start disabled; every change (`cmd.flow.patch`, rename, move, delete, category) is refused with a clear code; duplicate makes a normal flow in the data folder. A flow of the user with the same ID as a demo: decide and document (the demo wins, or it is not loaded, with a log line).
4. **Manager:** the category "Demonstration" (fixed name from the language file, not renamable, not deletable, always at the end or where v1 had it); delete or rename of a demo asks whether to hide all demos instead (as v1); the setting "Hide demonstration flows" in the settings dialog and in the import from v1 (`HideDemoFlows`).
5. **Editor:** a demo opens read only (no editing action, a hint in the status bar or a bar above the canvas with "Duplicate to change it"); the view (zoom, offset) is not written.
6. **Tests:** loaded with the mark, disabled at the first start, every change refused, duplicate editable, hidden by the setting, the editor refuses an edit (headless); the look is checked by the owner (manual check 12).

## Acceptance criteria

- The tests of task 6 are green; REQ-MGR-060 is updated; the documents of task 1 are updated.

## Not part of this

A check for updates (a feature of its own, off until the user switches it on, REQ-SEC-050); more demos than v1.
