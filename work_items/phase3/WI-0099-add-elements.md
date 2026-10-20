# WI-0099 Editor: add elements, class list by category and user level

Size: M · Depends on: WI-0098 · Blocks: WI-0100, WI-0102, WI-0106

## Goal

The user adds an action, a condition, a loop or a trigger from the fields at the top left of the canvas and chooses its class from a list grouped by category. The list shows only the classes of the user's level and marks the experimental ones. Requirements: REQ-EDT-050 (S0006 part), REQ-USE-010 (the list), REQ-USE-020 (the list).

## Read first

`AGENTS.md`; `doc/ELEMENT-API-V2.md` 2 (`Level`, `Stability`, `Category`, `Parameters`, `GenerateName`); `doc/PROTOCOL.md` 4.2 (setting `userLevel`); `src/ui_common/`; WI-0091 (how the questions are answered headless); v1: `v1/Source_Editor/User Interface/Editor GUI User Input.ahk` (the fields, about lines 160 to 250), `Element settings other.ahk` (`ElementSettingsElementClassSelector`), `v1/Source_Common/Elements/Manage Elements.ahk` (`Element_New`).

## Tasks

1. **The fields:** a click creates an element of that kind under the mouse. The element follows the mouse until a click, or until the release when the button is held (v1). Esc cancels.
2. **The class list:** a tree by category (a class may name several categories, separated by `|`, as in v1) with the classes of the kind, filtered by `userLevel`; the class that the element has is always shown. Experimental classes are marked (REQ-USE-020). OK or a double click chooses, Cancel cancels. It is a `ui_common/` window that does not block the message path; the texts follow the language.
3. **The new element:** the default values of `Parameters`, the default name from `GenerateName` under `try/catch` (fallback: the display name of the class), `StandardName` true, and `package` and `packageVersion` from the registry. A loop gets the default height of its bar. A trigger is the `DefaultTrigger` when it is the first manual trigger.
4. **One patch** `element.add`, one undo step. Cancel at any point leaves nothing.
5. **Hook for S0007:** after the choice of the class the settings dialog will open (WI-0106); until then the element is added at once.
6. **Tests** (headless, the list answered by the test): every kind, the filter for the three levels, the mark of an experimental class, cancel at every step, undo.

## Acceptance criteria

- The tests of task 6 are green. REQ-EDT-050, REQ-USE-010 and REQ-USE-020 are updated.

## Not part of this

The settings dialog (WI-0106); a new element at the end of a new connection (WI-0100).
