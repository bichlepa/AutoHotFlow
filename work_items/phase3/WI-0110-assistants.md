# WI-0110 Assistants: window information, color, mouse position

Size: M · Depends on: WI-0106 · Blocks: WI-0114

## Goal

The element settings help to fill in window information by pointing at a window, a color (chosen, or picked from the screen) and a mouse position. Requirements: REQ-EDT-130.

## Read first

`AGENTS.md`; `doc/CONVENTIONS.md` (rule 3: no `Sleep` loop); `doc/howto/gui-and-hotkeys.md`; `src/elements/Default/lib/WindowIdent.ahk` (the `Button` field of `Trigger_Hotkey`); v1: `v1/Source_Editor/Assistants/Get window information.ahk`, `Mouse tracker.ahk`, `Choose Color.ahk`, `v1/Source_Editor/API/API for Elements.ahk` (`x_assistant_*`).

## Tasks

1. **Wiring:** a `Button` field of the schema names its assistant (the v1 keys); the form calls it, and the assistant writes the chosen values into the form (`SetValue`).
2. **Window information:** the user points at a window (a timer reads the window under the mouse; a key or a click takes it). The assistant shows title, class, process, control and the other values of v1, and returns the fields the element asks for (`WindowIdent`).
3. **Color:** the Windows color dialog, and a picker that reads the pixel under the mouse. Check whether the modal color dialog keeps the pipe handling going, as WI-0069 checked for `FileSelect`; if it does not, use an own window.
4. **Mouse position:** a tracker with screen, window and client coordinates.
5. **Rules:** every assistant is a window of the editor process; no hook or hotkey stays behind after it closes; physical and logical pixels are handled correctly (DPI).
6. **Tests:** model tests with a fake window and pixel source (headless); gui tests (owner) for the real pointing.

## Acceptance criteria

- The tests of task 6 are green (gui: written). REQ-EDT-130 is updated.

## Not part of this

Assistants of the elements of S0008 that v1 does not have.
