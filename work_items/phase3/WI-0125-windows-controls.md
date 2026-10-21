# WI-0125 Windows and controls

Size: L · Depends on: WI-0116; corpus "file test": WI-0118, WI-0120, WI-0121, WI-0123 · Blocks: WI-0126, WI-0128, WI-0132, WI-0135

## Goal

The window and control elements of v1 exist in v2, as workers, with the window identification of `Trigger_Hotkey` (E0060) as their shared library. Requirements: REQ-ELM-360.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Activate_Window` | worker | wait with a timeout as in v1 |
| `Action_Show_Window` | worker | |
| `Action_Hide_Window` | worker | |
| `Action_Close_Window` | worker | close or kill (`WinCloseMethod`) |
| `Action_Move_Window` | worker | position, size, maximize, minimize, restore; DPI of the monitor |
| `Action_Minimize_all_windows` | worker | |
| `Action_Get_Control_Text` | worker | identify the control by class, text or ID (`IdentifyControlBy`) |
| `Action_Set_control_text` | worker | |
| `Condition_Window_Active` | worker | |
| `Condition_Window_Exists` | worker | with hidden windows (`FindHiddenWindow`) |

## Read first

The common part of the element packages (README S0008); `src/elements/Default/lib/WindowIdent.ahk`, `src/elements/Default/Triggers/Trigger_Hotkey.ahk`, `tests/ahk/element_window_ident.test.ahk`; `src/editor/assist/` (the window assistant, WI-0110); `tests/integration/helpers/hotkey_window.ahk`; v1: `v1/Source_Elements/Default/common/Window functions.ahk`; AutoHotkey docs: `WinExist`, `WinWait`, `WinActivate`, `ControlGetText`, `DetectHiddenWindows`, `SetTitleMatchMode`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **One window identification:** every class uses `WindowIdent` (title, class, process, text, exclusions, match mode, hidden windows) as the hotkey trigger does; the parameters and the assistant button are those of v1. Extend the library where the elements need more (controls), with its tests.
2. **Test windows:** own windows of the test helpers (a GUI with a known title, controls with known text and class), started by the test and closed after it; no window of the user is touched. A test that activates a window holds the input lock (it takes the focus).
3. **The process name** of an AutoHotFlow window is `AutoHotkey64.exe` until S0009; flows of v1 name `AutoHotFlow.exe` (fix list of the corpus, MIGRATION).
4. **Corpus:** "file test" (`Flow 1384439262`) on a copy that works in a temporary folder and with an own test program instead of Notepad where needed.

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

The window triggers (WI-0132); keys and clicks sent to a control (WI-0126).
