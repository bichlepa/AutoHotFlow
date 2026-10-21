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
