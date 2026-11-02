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

## Result

Branch `wip/wi0128`, commits (on top of `v2-port` at the start): `976b3eca` (Dialogs.InputWindow and its test provider answer, documents), `791e3527` (the three element classes, help pages, language keys, tests), `8cc6a3f2` (corpus headless part and gui check), plus the document commit that follows this section.

**Done**
- `Action_Input_Box` (worker): the options of v1; the window is `Dialogs.InputWindow` (new seam function, `DialogWindow.Input`); output variable empty on cancel, close and timeout; `A_UserAction` ok / timeout / cancel / close.
- `Action_Select_file` and `Action_Select_Folder` (worker): `Dialogs.FileSelect` and `Dialogs.DirSelect` with the v1 options; cancel is an exception with the v1 text.
- Help pages corrected for v2 (`Input_Box`, `Select_file`, `Select_Folder`; folder page renamed to the class name), generated HTML.
- Language keys: one new key in `en.ini` and `de.ini` (folder dialog message).
- Tests: `tests/integration/test_dialog_elements.py` (18 test cases, headless with the test provider, real worker sessions).
- Corpus "Dialog test" (Flow 130786371): trigger "Input Normal" as saved, headless (`test_v1_dialog_test_input_normal_runs_headless_with_a_scripted_input_box`), gui check of the input window (`test_input_window_shows_its_field_and_times_out`, owner only).
- REQ-ELM-270 rows updated, MIGRATION M-0168 (input box timeout value), ELEMENT-API-V2 3.3 and TEST-STRATEGY 9a updated, group table entries, indexes regenerated.

**Not done**
- The "Dialog test" flow as a whole (gui part: process name, control names of the v2 window, keystrokes). Stays in `PENDING`. OPEN-ITEMS F-0197.

**Tests (run, commit as noted)**
- `20261102-110303-8168` (on the uncommitted seam and element code): `test_dialog_elements.py` 18 passed.
- `20261102-110628-26480`: 18 passed, 1 failed (empty-root case, my test was wrong; removed; the element had a dead guard, removed).
- `20261102-110835-26688`, `python -m pytest tests -q --changed-from v2-port`, 1446 passed, 2 skipped, 3 failed: `test_doc_index` (indexes outdated at that time, regenerated after), `test_core_settings` `Action_Get_index_of_element_in_list` and `test_worker_reports_not_busy_after_a_cancel_too` (load-sensitive; listed as F-0191 for the worker one). Both rerun serially: `20261102-113050-4520`, 30 passed.
- Gui tests: not run (agent rule).

**Decisions**
- New seam function `Dialogs.InputWindow` instead of extending `Dialogs.Window`: the input window needs a field, masks, lines and a countdown. Alternative: one generic window; rejected for size.
- A_UserAction "timeout" on timeout (help of v1) instead of v1 code "Cancel": MIGRATION M-0168.
- Category "User interaction" only (v2 has one category; v1 had two for the file elements).
- MIGRATION ID M-0168 chosen because M-0167 is used twice in `v2-port` (F-0198).

**Findings**
- F-0197, F-0198 in `doc/OPEN-ITEMS.md`.
- `Button text` vs `Button Text` lookups are case insensitive (LangTable `CaseSense := "Off"`), so no fix needed.

**Verified / assumed / not checked**
- Verified: 18 headless element tests and the corpus headless test pass; arch check passes; help and group tests pass.
- Assumed: the AHK `Gui` edit options `Number` and `Password` behave as the docs say (docs read, not run in a window).
- Not checked: the three real windows (look, DPI, focus), the flow "Dialog test" with its real windows (owner gui part).
