# WI-0098 Editor: select (click, Ctrl, rectangle) and move, loop height

Size: M · Depends on: WI-0096, WI-0097 · Blocks: WI-0099, WI-0100, WI-0101

## Goal

The user selects elements and connections with the mouse and with Ctrl+A, draws a selection rectangle with the left button (E0094), moves the selection, and changes the height of a loop. Requirements: REQ-EDT-060, REQ-EDT-030 (the right button moves the view).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0094; `doc/PROTOCOL.md` 4.11 (mouse paragraph); WI-0090 (result: mouse capture, no `Sleep` loop); `src/editor/EditorWindow.ahk`; v1: `v1/Source_Editor/User Interface/Editor GUI User Input.ahk` (`clickOnPicture`, `ui_moveSelectedElements`, `ui_UpdateStatusbartext`).

## Tasks

1. **Docs first:** PROTOCOL 4.11, mouse paragraph (left button: select, rectangle, move; right button: the view; Esc). MIGRATION (E0094: a left drag on an empty place no longer moves the view). The texts of REQ-EDT-030 and REQ-EDT-060.
2. **Click:** a click selects one element or connection and unselects the others; Ctrl+click toggles one; a click on an empty place unselects all; Ctrl+A selects all. The status bar shows what v1 shows for the selection (read in `ui_UpdateStatusbartext`).
3. **Rectangle (E0094):** a left drag on an empty place draws the rectangle, and Ctrl adds to the selection. Decide whether an element must lie fully inside or only touch the rectangle, and document it. Connections between selected elements are selected too.
4. **Move:** dragging a selected element moves the whole selection. The drop snaps to the grid of 35 and sends one patch `element.update` (x, y) for every moved element, one undo step. Esc or the right button during the drag cancels: no patch, no step. The wheel still zooms during a drag (v1).
5. **Loop height:** dragging the tail of a selected loop changes `HeightOfVerticalBar`, snapped to the grid, at least two grid steps (v1).
6. **Keys:** `WM_KEYDOWN` of the editor window, never a hotkey. Esc and Ctrl+A belong to this package; the key table is the place where the later packages add their keys.
7. **Headless driver:** `cmd.test.mouse {button, action: down/move/up/double, x, y, ctrl?, shift?}` and `cmd.test.key {key, ctrl?, shift?}`. They go through the same handlers as the window, so the real input path is tested headless.
8. **Tests:** e2e for every case above. The gui test `tests/fault/test_editor_mouse_gui.py` moves the view with the right button now; a new gui test (owner) covers click, rectangle and drag.

## Acceptance criteria

- The tests of task 8 are green (gui: written, the owner runs them). PROTOCOL and MIGRATION are updated. REQ-EDT-060 and REQ-EDT-030 are updated.

## Not part of this

Adding (WI-0099), connecting (WI-0100), deleting and the clipboard (WI-0101), the menus (WI-0102).
