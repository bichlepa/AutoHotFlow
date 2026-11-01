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

## Result

Status: the nine classes are ported; the acceptance criteria of the element package hold except where marked open below.

- **Classes** (`src/elements/Default/Actions|Conditions`): Click, Move mouse, Drag with mouse, Get mouse position, Send keystrokes, Send keystrokes to control, Set lock key, Block user input, Key is down. Shared code: `lib/MouseOps.ahk` (send mode and coordinate mode of this thread). Help pages written for v2, HTML generated.
- **Seam** (`SystemOps`): `BlockInput(state)` remembers the block of the process, `ReleaseInput()` ends it; `MouseGetPos(flag)` (a read, so a test gets a fixed position). The worker calls `ReleaseInput` in its orderly shutdown (`src/worker/Worker.ahk`). ELEMENT-API-V2 3.3a updated.
- **Hotkey test (task 2) not done:** the corpus flow `Flow 2133155705` stays in PENDING with no missing elements. Decision needed (below).
- **gui tests (task 1, owner) not written:** decision needed (below).
- **Open:** a blocked input after a killed worker (OPEN-ITEMS F-9001*, M-0156). Logical key state across processes (HOW-TO, gui-and-hotkeys).

Tests (run IDs at the commit of the work before the commits are made):
- `tests/integration/test_mouse_keyboard_elements.py`: 28 passed (run 20261101-210425-23064, serial, after the fixes).
- `tests/ahk/element_system_ops.test.ahk` (via `test_ahk_runner.py`): 5 passed (run 20261101-210424-22956); the case for BlockInput was corrected (the function returns nothing, the state is checked).
- `python -m pytest tests -q --changed-from v2-port`: run 20261101-205737-14164, 1087 passed, 2 skipped, 3 failed; the 3 failures were fixed (BlockInput unit test; physical "no" test moved into the `input` xdist group) and the fixed tests were re-run as above. The full selection was not run again after the fixes.
- Schema, groups, help, element includes, architecture (`tests/schema`, `test_groups.py`, `test_help.py`, `test_element_includes.py`, `test_architecture.py`): 204 passed (run 20261101-210626-7056, after the M-0155 entries).

Decisions (taken, to be reviewed):
- Click: speed through `SetDefaultMouseSpeed` (v2 `Click` has no speed); one `Click` call with an options string (M-0153).
- Numbers of the mouse elements rounded to whole numbers (M-0154, the rule of Beep).
- `MouseGetPos` added to the seam: it only reads, but a test needs a fixed position.
- Send modes Input, Event, Play plus the Raw checkbox of v1 (v2 `SendMode` has no "Raw" send mode).
- Key is down and Get mouse position count as acting on the system (import warning).

Decision needed (owner):
- gui tests of task 1 (real clicks, keys into an own test window): not written; agents do not run gui tests.
- Hotkey test flow: a copy with unassigned keys needs the Ctrl+F7 part removed or marked gui, and every test entry registers the provider, so the real `Send` never runs headless; the trigger path is covered by `test_hotkey_input.py`.

Not checked:
- BlockInput needs administrator rights or not (the help does not say; v1 behaviour not run).
- Logical key state of a key held by another process (the physical state was tested).
- Coordinate modes on the real mouse (the seam records the arguments; the mode is set by the element).
- Rounding of the numbers: no separate test.
- The real desktop: mouse, keys, lock keys, block input (owner's manual check).
