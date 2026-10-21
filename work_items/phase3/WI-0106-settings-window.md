# WI-0106 Element settings window: every field type, content types, MIGRATION places, new element

Size: L · Depends on: WI-0105, WI-0099 · Blocks: WI-0108, WI-0110, WI-0111 (the help button)

## Goal

The user opens the settings of an element and changes them in a window drawn from the form model, as in v1. A new element opens its settings after the choice of its class. Requirements: REQ-EDT-120, REQ-USE-020 (the note in the settings), REQ-MIG-070 (editor part), REQ-USE-090 (the dialog).

## Read first

`AGENTS.md`; WI-0105 (result); `src/ui_common/`, `src/core/GuiLayout.ahk`; `doc/howto/gui-and-hotkeys.md` (DPI); `doc/ARCHITECTURE.md` 7 (MIGRATION places); v1: `v1/Source_Editor/User Interface/Element settings.ahk` (the layout, the scroll area, the buttons), `v1/Icons/` (`expression.ico`, `string.ico`, `VariableName.ico`).

## Tasks

1. **The window draws the form:**
   - Every field type becomes a Gui control: a hotkey control, date and time, the week days as check boxes, a slider, and file or folder with a button that opens the non-blocking file dialog of `ui_common/`.
   - Each edit field has the icon of its content type next to it, and the selector when it has `contentID`.
   - Warnings stand next to their fields.
   - The name field has its option "standard name".
   - The fields are in a scroll area; OK, Cancel and Help stay visible.
   - DPI and language are handled.
2. **Opening:** a double click on the element, the edit button, the context menu and the menu entry. Decide whether the canvas takes edits while the dialog is open (v1 disabled the editor; the live states go on in any case) and document it.
3. **OK** sends one `element.update` patch (one undo step), only when something changed. Cancel sends nothing.
4. **New element:** the class list, then this dialog; OK adds the element (the hook of WI-0099), Cancel adds nothing.
5. **MIGRATION places:** a field with a place shows its IDs and the v1 text (read-only). Changing the field resolves the place (WI-0093).
6. **Unknown class or missing package:** a read-only list of the parameters (REQ-MIG-070).
7. **Experimental class:** the note "This element is experimental!" (REQ-USE-020).
8. **Change of the class:** read in v1 whether the class of an existing element can be changed; if so, as in v1.
9. **Tests:** headless `cmd.test.form {action: open/set/ok/cancel, ...}` through the model; a gui test (owner): open, change, OK at 100 % and 225 %.

## Acceptance criteria

- The tests of task 9 are green (gui: written). PROTOCOL 4.11 has the test commands. REQ-EDT-120, REQ-USE-020, REQ-MIG-070 and REQ-USE-090 are updated.

## Not part of this

The help window itself (WI-0111); the assistants (WI-0110); the expression check (WI-0108).

## Refinement from WI-0104 (proposal, not decided)

Written by the acceptance of S0006 (WI-0104, E0095). The project owner decides whether this stands; the package may refine it again and says so in its result.

- Today `EditorAdd._Chosen` adds the element at once with its defaults. The form goes between the class choice and the add: choice, form, OK = one `element.add`; Cancel = nothing. The e2e test `test_the_answer_adds_the_element_at_the_placed_place_with_its_defaults_and_selects_it` changes with it (say so in the result).
- The entries `edit` (context menu of an element and the Edit menu) are disabled in `EditorMenus.ContextSpec` and `BarSpec` until this package; enable them in the same place, and the double click of `EditorPointer` opens the form (the plan says so; it is not wired yet).
- `EditorMenus._Act` has the placeholder for `edit`: it must not fall through to nothing silently. Keep the try/catch of `Run` (WI-0104) around it.
