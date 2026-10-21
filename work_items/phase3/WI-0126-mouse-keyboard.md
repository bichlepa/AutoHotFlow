# WI-0126 Mouse and keyboard

Size: M · Depends on: WI-0117, WI-0125 · Blocks: WI-0128 (corpus "Dialog test"), WI-0135

## Goal

The mouse and keyboard elements of v1 exist in v2. Everything that acts on the whole desktop goes through `SystemOps` (E0103) and is tested by its recorded call; keys and clicks sent to a control of an own test window run for real. Requirements: REQ-ELM-370.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Click` | worker | `SystemOps`; buttons, count, position, coordinate mode, the mouse assistant |
| `Action_Move_Mouse` | worker | `SystemOps`; speed, relative or absolute |
| `Action_Drag_With_Mouse` | worker | `SystemOps` |
| `Action_Get_Mouse_Position` | worker | coordinate modes; through `SystemOps` if a test needs a fixed position |
| `Action_Send_keystrokes` | worker | `SystemOps`; the send modes of v1 (Input, Event, Play, Raw); the key names of v2 (help, WI-0112 list) |
| `Action_Send_Keystrokes_To_Control` | worker | `ControlSend`, real (no focus needed) |
| `Action_Set_Lock_Key` | worker | `SystemOps` |
| `Action_Block_User_Input` | worker | `SystemOps`; check whether `BlockInput` needs administrator rights and what v1 did; the input is never left blocked when the worker ends (a test with a killed worker through the provider's record) |
| `Condition_Key_Is_Down` | worker | `GetKeyState`, logical or physical |

## Read first

The common part of the element packages (README S0008); `doc/TEST-STRATEGY.md` "Input tests" (input lock, unassigned keys, the input desktop check); `tests/integration/test_hotkey_input.py`, `tests/support/inputlock.py`; `doc/howto/gui-and-hotkeys.md` (the keys); `src/editor/assist/MouseAssistant.ahk`; AutoHotkey docs: `Send`, `SendMode`, `Click`, `MouseMove`, `MouseClickDrag`, `ControlSend`, `GetKeyState`, `BlockInput`, `CoordMode`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Two levels of tests:** headless, the recorded call with the computed arguments (the key text, the coordinates after the coordinate mode, the button and count); for real, `Action_Send_Keystrokes_To_Control` into an own test window. A few `gui` tests (owner) send real keys and clicks to an own test window.
2. **Hotkey test:** the "Hotkey test" flow (`Flow 2133155705`) sends F6 and Ctrl+F7 to the active window and catches them with `Trigger_Hotkey`. Run it on a copy with unassigned keys through the real `Send` under the input lock (the input tests do the same), or, if a real send is needed only for the modifier case, mark that part `gui` (fix list, MIGRATION ID).

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

Hotstrings (WI-0131); a recorder of mouse and keys.
