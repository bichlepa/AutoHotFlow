# WI-0088 Editor role: model, resync, window, headless driver

Size: L · Depends on: WI-0085, WI-0086, WI-0087 · Blocks: WI-0089, WI-0090, WI-0091

## Goal

The real editor replaces the placeholder: a role that loads its flow, follows it through the events of the engine and draws it in a window of its own; headless for the tests. Requirements: REQ-EDT-010, REQ-EDT-020, REQ-EDT-040 (part), REQ-ROB-040 (editor), REQ-EXE-140 (editor part), REQ-MIG-070 (editor display).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 2.1, 3, 4.1, 6; `doc/CONVENTIONS.md`; `doc/PROTOCOL.md` 3, 4.2, 4.3, 4.8 (the resync of the manager), 4.9, 5, 5a; `src/manager/Manager.ahk`, `ManagerModel.ahk`, `ManagerDriver.ahk` (the pattern of model, view and driver); `src/ui_common/`; WI-0078 (language change without a restart); WI-0084, WI-0085, WI-0086, WI-0087 (results); `v1/Source_Editor/User Interface/Editor GUI.ahk`.

## Tasks

1. **Docs first:** PROTOCOL section "Editor" (subscriptions `flow:<flowId>`, `engine`, `settings`, `process`; the resync rules; `cmd.editor.show`; the test commands), ARCHITECTURE 3 (editor row) and 8 (`src/editor/` and `src/editor/render/`).
2. **Model** `EditorModel`, no GUI code: definition and `rev`, run states, trigger states, flow state, warnings, view, the connection state of the engine. Resync (`cmd.flow.get` and `cmd.flow.runstate`) at the start, after `evt.engine.ready` or `evt.engine.restarted`, on a new `epoch` and after a reconnect; `seq` only discards events older than the answer (the editor sees a few topics, so gaps in `seq` are normal). Events: `evt.flow.state`, `evt.trigger.state`, `evt.element.state`, `evt.element.warning`, `evt.flow.committed` (get the definition again), `evt.flow.list.changed` with the flow removed (the editor closes, the manager shows the notice), `evt.settings.changed` (language). A flow that does not exist at the start (`not_found`): notice and clean end.
3. **Window** `EditorWindow` on `ui_common/UiWindow`: the canvas (the client area above the status bar) shows the back buffer in `WM_PAINT` and answers `WM_ERASEBKGND` (no flicker); a frame only when the scene changed, at most one per 33 ms; title "AutoHotFlow Editor - <flow name>" with the Lang keys of v1, renamed on a language change and a rename of the flow. First size 90 % of the work area of its monitor (v1), or the remembered place if WI-0077/WI-0078 keep window places. `cmd.editor.show` shows and activates it. The close box ends the role with a clean bye (`Role.ByeFn`); `cmd.app.prepareExit` answers without cancel (nothing unsaved in S0005).
4. **Headless driver** (`--headless`): no window; the renderer draws into an offscreen bitmap of a given size. `cmd.test.state` (rev, number of elements and connections, the states, the view, frames, the last and the slowest frame time, connection state), `cmd.test.render {w, h, probes}` (draws now; returns the time and the colors at given flow points), `cmd.test.close`.
5. **Entry:** `src/entry/editor.ahk` registers the real role; it keeps `#NoTrayIcon` until WI-0091 shows the icon. `tests/integration/test_entry.py` is adapted (E0046).
6. **Snapshot of the role** (PROTOCOL 4.9): flow ID, rev, element count, frames, mean and slowest frame time, the last resync and its reason.
7. **Tests** (e2e, headless): open, loaded and drawn (probes); a rename in the manager changes the title; a deletion closes the editor; an editor opened while the flow runs shows the running element; the engine killed: the editor shows the current state again; the editor killed: the flow keeps running and the other editor too; two editors of two flows at once; a missing flow ends the editor cleanly. `gui` test (owner): the window opens and shows the flow.

**Carried over from WI-0087 (see the finding about editor-open tests):** the editor of WI-0088 stays alive, so make the two tests with a running editor deterministic (they depend on back-to-back requests today), add tests for `FlowIdOk`, the clean bye as a planned end, the crashed editor that is not restarted and the slot of a dead editor in the limit, and close the short race of `cmd.editor.show` to an editor that just died.

## Acceptance criteria

- The tests of task 7 are green; foundation tier green; PROTOCOL and ARCHITECTURE updated; REQ-EDT-010, REQ-EDT-020, REQ-ROB-040, REQ-EXE-140, REQ-MIG-070 updated.

## Not part of this

Fading, connection taken, warning marks and the event load (WI-0089); zoom, move, tooltip, status bar, DPI change (WI-0090); the tray icon (WI-0091).
