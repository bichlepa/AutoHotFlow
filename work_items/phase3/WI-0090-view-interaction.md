# WI-0090 View: zoom, move, tooltip, status bar, DPI

Size: M · Depends on: WI-0088 · Blocks: WI-0092

## Goal

The user zooms and moves the view as in v1, sees a tooltip with the kind, class and name of the element under the mouse, and reads the offset, the zoom and the number of elements in the status bar. The flow is sharp and has the same size on every screen, also when the window moves to a screen with another scaling. Requirements: REQ-EDT-020 (tooltip), REQ-EDT-030 (zoom and move; saving the view is S0006, E0086), REQ-USE-090 (editor).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 2.1; `doc/CONVENTIONS.md` (rule 3: no `Sleep` loop); `doc/howto/gui-and-hotkeys.md` (DPI entries, open menus); `src/core/GuiLayout.ahk`; WI-0084 (view math), WI-0088 (result); `v1/Source_Editor/User Interface/Editor GUI User Input.ahk` (`ui_scrollwithMouse`, `mouse_wheel`), `Editor GUI.ahk` (status bar text), `Tooltip.ahk`.

## Tasks

1. **Zoom** with the mouse wheel at the mouse point (factor 1.1, 0.1 to 3, as v1).
2. **Move** by dragging with the right mouse button, and with the left one on an empty place (as v1; S0006 may change the left button for selecting), through `WM_MOUSEMOVE` with mouse capture, never a loop with `Sleep` (v1 scrolled in such a loop).
3. **Size:** the canvas follows the window; a new back buffer of the new size.
4. **Tooltip** after the mouse rests about 0.5 s on an element: kind, class (its display name) and name; for a trigger its arming error, for an element its exception, the first warning texts and its MIGRATION IDs; on a connection its type.
5. **Status bar** (v1 texts): offset, zoom, number of elements.
6. **DPI:** `WM_DPICHANGED` sets the new scale and the suggested window rectangle; the flow keeps its physical size.
7. **Tests:** headless driver commands for the view (`cmd.test.view {zoomAt, drag, size, dpi}`, `cmd.test.hover {x, y}`) with the model's view and tooltip text checked; `gui` test (owner) for real mouse input and a second screen if available.

## Acceptance criteria

- The tests of task 7 are green; REQ-EDT-030 and REQ-USE-090 updated (the manual check in WI-0092 closes the DPI part).

## Not part of this

Saving the view (S0006, E0086); keyboard input and selection (S0006).
