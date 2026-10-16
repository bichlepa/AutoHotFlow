# WI-0064 `Trigger_Hotkey` with window conditions

Size: L · Depends on: WI-0062 · Blocks: WI-0067

## Goal

`Trigger_Hotkey` works completely, with its options and its window conditions (E0060). The window identification it needs is a shared library of the package `Default` that the window elements and triggers of S0008 reuse. Two flows with the same hotkey both fire. Tests send real input without disturbing the user (E0059). Requirements: REQ-TRG-230 (row `Trigger_Hotkey`), REQ-TRG-010.

## Read first

As WI-0063, plus `doc/ELEMENT-API-V2.md` 5 (the planned v2 form of this class), MIGRATION M-0003, the v1 class `v1/Source_Elements/Default/Triggers/Hotkey.ahk` and its help text, the v1 window identification (the helper behind `x_GetWindowIdentificationParameters` or similar in `v1/Source_Execution/API/` and `v1/Source_Elements/Default/`; read the help text of an element that uses it, e.g. `Window_Exists`), the AHK v2 docs `lib/Hotkey.htm`, `lib/HotIf.htm`, `misc/WinTitle.htm`, `lib/SendInput.htm` (or `Send.htm`), `KeyList.htm` (virtual keys), `doc/TEST-STRATEGY.md` 6 (`gui` tier), `tests/support/admission.py`.

## Tasks

1. **Spike first (E0059):** a script registers a hotkey on an unassigned virtual key (`vk97` to `vk9F`), once through `RegisterHotkey` (plain) and once through the keyboard hook (`$` or `~`), another process sends the key with `SendInput`; both fire, and the window in the foreground shows nothing. Result in `doc/MEASUREMENTS.md` or a HOW-TO entry. If an unassigned key does not work, stop and report to the owner with the alternatives (F13 to F24, the `gui` tier only).
2. **Window identification** `src/elements/Default/lib/WindowIdent.ahk`: the parameters as v1 (`TitleMatchMode`, `Wintitle`, `excludeTitle`, `winText`, `ExcludeText`, `ahk_class`, `ahk_exe`, `ahk_id`, `ahk_pid`, `FindHiddenText`, `FindHiddenWindow`, and the button to read the window information as an editor field for S0007), a function that adds them to a parameter list (`AddIdentificationParameters(p, opts)`), and a match function that sets title match mode and hidden detection, finds a window and checks it against the excludes. Written for reuse: no hotkey code in it. AHK unit tests with hidden windows of the test process (`FindHiddenWindow`), so no window shows.
3. **`Trigger_Hotkey`** as `doc/ELEMENT-API-V2.md` 5: options `BlockKey` (`~`), `Wildcard` (`*`), `WhenRelease` (` up`), `UseWindow` (`Everywhere`, `WindowIsActive`, `WindowExists`, `WindowIsNotActive`, `WindowNotExists`) through `HotIf` with a function that uses `WindowIdent` (the `HotIfWin*` forms cannot exclude). `Disable` uses the same context (M-0003). A hotkey that cannot be set: `ElementError` with the v1 text. `TriggerVariables`: `A_Hotkey` (v1 `Element_postTrigger_Trigger_Hotkey`).
4. **Shared registration in the host:** the class keeps, per hotkey text and context, one registration and the list of armed triggers on it; a press fires every armed trigger of the list; `Disable` of one removes it from the list and turns the hotkey off only when the list is empty. Two flows with the same hotkey and the same window condition then both fire, and disabling one keeps the other. MIGRATION entry (in v1 the later one replaced the earlier and disabling one turned off both; read in the code to confirm).
5. **Unit test of the hotkey text:** every combination of the options gives the expected text; the context function for each `UseWindow` value.
6. **Input tests (E0059)** `tests/integration/test_hotkey_input.py`:
   - A machine-wide input lock (`tests/support/inputlock.py`, a lock file next to the admission files, held for one test, stale after a timeout): two runs never send keys at the same time. All input tests in one `xdist_group`.
   - Skipped with a clear reason when there is no input desktop (locked workstation, UAC prompt in front): `SendInput` returns 0 or a probe key does not arrive.
   - Normal tier, with unassigned keys and no modifier: plain, `~` (the key passes on), ` up`, `WindowExists`/`WindowNotExists` (hidden test window), `WindowIsActive`/`WindowIsNotActive` against the window that is active anyway (no change of focus), two flows on one key, disable of one of them, an error of one trigger does not stop another.
   - `gui` tier (run by the owner, never by an agent): combinations with modifiers (`^!+`), `Wildcard` with a held modifier, a real key that a user may press. VS Code task `Test: hotkey input with key combinations (gui)` (rule 10).
   - A test that finds a modifier held (`GetKeyState`) waits briefly and tries once more.

## Acceptance criteria

- The spike result is recorded; the tests of tasks 2, 5 and 6 (normal tier) are green, serial and parallel, also when another test run runs at the same time (the lock).
- The `gui` tests exist and have a VS Code task; the owner runs them in the acceptance (WI-0067).

## Docs

`doc/ELEMENT-API-V2.md` 5 (the example becomes the real class or points to it), `doc/MIGRATION.md` M-0003 (implemented) and task 4, `doc/TEST-STRATEGY.md` (input tests, the lock, what runs in `gui`), HOW-TO entries (hotkeys, `HotIf`, `SendInput`), `doc/REQUIREMENTS.md` REQ-TRG-230, then `python tools/doc_index.py`.

## Not part of this

`Trigger_Hotstring` (S0008), the window elements and triggers that reuse `WindowIdent` (S0008), the window info wizard in the editor (S0007), warning about conflicting hotkeys (REQ-TRG-040, `later`).
