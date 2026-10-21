# WI-0128 Input box, file and folder selection

Size: M · Depends on: –; corpus "Dialog test": WI-0119, WI-0125, WI-0126 · Blocks: WI-0135

## Goal

The last three dialog elements of v1 exist in v2, as workers, through the dialog seam (E0038), so the tests answer them from a script. Requirements: REQ-ELM-270.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Input_Box` | worker | the options of v1: title, text, default, size, multi-line rows, password, buttons with own labels, cancel button, timeout with its result, the results on close and dismiss (`IfClose`, `IfDismiss`, `OnTimeout`) |
| `Action_Select_file` | worker | `Dialogs.FileSelect` with the options of v1 (several files, filter, root) |
| `Action_Select_Folder` | worker | `Dialogs.DirSelect` |

## Read first

The common part of the element packages (README S0008); `doc/ELEMENT-API-V2.md` 3.3; `src/elements/base/Dialogs.ahk`, `src/elements/base/DialogWindow.ahk`; `src/elements/Default/Actions/Action_Message_Box.ahk`, `Condition_Confirmation_Dialog.ahk`; `tests/integration/helpers/TestDialogProvider.ahk`, `tests/integration/test_core_e_dialogs.py`; v1: `Input_Box.ahk` (its own window), `Select_file.ahk`, `Select_folder.ahk` (dialogs in an AHK thread).

## Tasks

The common tasks (README S0008) for every class, and:

1. **The input box** is a window of its own in v1 (more than `InputBox` can do). Build it on `Dialogs.Window` or as a new `Dialogs` function with a product window in `src/elements/base/` and an answer of the test provider; document the function in ELEMENT-API-V2 3.3 and TEST-STRATEGY 9a.
2. **Corpus:** "Dialog test" (`Flow 130786371`). It reads the controls of its own input box by title and class (`ahk_exe AutoHotFlow.exe`, `AutoHotkeyGUI`, `Edit1`, `Button1`) and presses its buttons with `Action_Send_Keystrokes_To_Control`. This needs the real window, so the test of this flow is a `gui` test (TEST-STRATEGY 6: a test that opens a window), run by the owner, with the fixes it needs (process name, control names of the v2 window) in the fix list. If a part of the flow can run headless with the test provider (the input box answered from the script), add that as a second, headless test.
3. **gui test** (owner) for the three real dialogs.

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

New dialog types beyond v1.
