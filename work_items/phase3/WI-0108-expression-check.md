# WI-0108 Expressions checked while typing (REQ-EDT-200, E0096)

Size: S · Depends on: WI-0106 · Blocks: WI-0114

## Goal

An expression field of the element settings shows a syntax error, with its position, while the user types. Requirements: REQ-EDT-200.

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0096; `doc/EXPRESSION-LANGUAGE.md` section 10 (errors with their position) and the rules of the content type `String` (texts with embedded expressions); `src/expr/` (the parser); WI-0105 and WI-0106 (results).

## Tasks

1. **The check:** every field whose content type is an expression type (the list in ARCHITECTURE 7) is parsed when typing stops (about 300 ms, a timer, not at every key). An error becomes a warning at the field, with its position (and the place is marked if the control allows it). If the content type `String` embeds expressions, those parts are checked too. A parameter that the element evaluates itself as an expression or a script (`static V1Syntax`, ELEMENT-API-V2 2) is checked with the matching parser (REQ-EDT-200 names script fields; the script elements come with S0008, so the core set has only expressions, and a test element covers the script case).
2. **Cost:** the parse time of long scripts is bounded (measure a long text and record it in the result).
3. **Warnings, not refusals:** OK still works (v1 behaviour: warn).
4. **Tests:** model tests for a valid text, an invalid one, and the position of the error.

## Acceptance criteria

- The tests of task 4 are green. REQ-EDT-200 is updated.

## Not part of this

Syntax highlighting and completion (REQ-EDT-210, later); the variables known at the element (REQ-EDT-190, later).

## Refinement from WI-0104 (proposal, not decided)

Written by the acceptance of S0006 (WI-0104, E0095). The project owner decides whether this stands; the package may refine it again and says so in its result.

- The check while typing runs in the dialog's edit field. Keys typed there go to the dialog window, not to the editor's `WM_KEYDOWN` (EditorKeys is the editor window only), so Ctrl+Z in a field must not reach the draft: test it headless and by hand.

## Result (implementer, 2026-10-21)

Done: tasks 1 to 4. Commits on `wip/wi-108`: `55781642` (window test; fix of the defaults of an id Array), `c8ca2f33` (form model: `FormExpressions`, `ElementForm.CheckExpressions`, texts, model tests), `34fa2efc` (timer in `EditorSettings`, warning line in the window, e2e test, REQ-EDT-200 `done`, PROTOCOL 4.11, ELEMENT-API-V2 3.1), `2841aa39` (manual check 11), `5762fe26` (HOW-TO: one-shot timer restarts its delay).

**Decisions taken by the implementer** (the owner may change them):

- **The timer lives in the controller** (`EditorSettings`, 300 ms after the last change of a value, `CHECK_DELAY`), not in the window, so that the headless driver shows the same behaviour. The window only shows the warnings.
- **Length limit 4000 characters.** The parse of a script takes about 0.4 ms per line; measured with `Expr.Parse` (no cache, five runs each): a script of 3801 characters (125 lines) 47 to 63 ms per parse, an expression of 3990 characters 16 to 31 ms (it reports the depth limit, which is correct). A longer text is not parsed; the warning reads "Too long to check while typing: at most 4000 characters".
- **The place is not marked.** The warning gives the line and the column. Selecting the error part in the edit field would move the caret in the middle of typing, so it is not done ("if the control allows it" in the task).
- **Only the first error is shown**, with "(N more)" for the others. The parser's messages stay English (EXPRESSION-LANGUAGE section 10).
- **Checked kinds:** edit, multi-line edit and combo box fields with an expression content type (also the type chosen by `contentID`), and the parameters named in `V1Syntax` (`expression` or `script`). Not checked: String texts. **The refinement premise "String embeds expressions" is not in the documents:** ELEMENT-API-V2 3.1 and EXPRESSION-LANGUAGE 15.3 say that `%name%` in a String is variable substitution, not expression syntax. So nothing is checked there. The owner should confirm.
- **The check runs once at the opening** (synchronously, the same length limit applies), and after a class change.
- **A warning does not refuse OK** (checked: `EditorSettings.Ok` looks at no warning).

**Script fields:** no core element has a script field yet (S0008); the script case is covered by `Test.Action_TestExprParams` (V1Syntax `Script`).

**Refinement from WI-0104 (keys in a field):** verified by reading, not by a run. `EditorWindow._OnKey` returns when the message's window is not the editor's (`hwnd != this.hwnd`, `src/editor/EditorWindow.ahk`), and the settings are their own Gui. Ctrl+Z, Ctrl+Y and Del therefore act in the field. **Not run by hand:** manual check 11 (`doc/MANUAL-CHECKS.md`, section 11), steps 4 and 5, is the owner's.

**Tests** (commit = the state of the run):

- **Outside the task, fixed:** `NewElementCatalog.Defaults` used an id Array as a key (a parameter with several ids, such as `Action_TestExprParams`): opening a new element of such a class failed with a type error. Fixed in `55781642` with a test (`tests/ahk/editor_settings_window.test.ahk`, `MultiIdDefaults`).
- `tests/ahk/editor_settings_window.test.ahk`: 14 passed incl. the window's syntax warning line `WindowShowsSyntaxWarning` (run 20261021-195029-20628, the content of `55781642`).
- `tests/ahk/editor_form_expr.test.ahk` (new, group `editor-form`): 12 cases and the file-completion test, 13 passed (run 20261021-194229-19656, the content of `c8ca2f33`).
- `tests/test_groups.py`: 47 passed (run 20261021-194236-21300).
- `tests/test_ahk_runner.py -k editor`: 223 passed (run 20261021-194434-5716, at `34fa2efc`).
- `tests/e2e/test_editor_settings.py` (headless, real supervisor): 13 passed incl. the new `test_a_syntax_error_of_an_expression_is_shown_after_typing_stops_and_goes_when_fixed` (run 20261021-194444-12360, at `34fa2efc`).
- `tools/arch_check.py`: 0 violations. `tools/doc_index.py --check`: up to date.
- Fast tier `python -m pytest tests -q` on `5762fe26`: see the final report.

**Not checked:** the gui tests (not run, owner's); the hand check of section 11; a long script with the window open (only the parse cost, not the redraw); German texts of the parser messages (they stay English by design).
