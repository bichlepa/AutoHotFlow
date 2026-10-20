# WI-0114 Acceptance S0007

Size: M · Depends on: WI-0105 to WI-0113, WI-0115 · Blocks: S0008

## Goal

S0007 is demonstrably finished and the documents match the code. Afterwards S0008 is detailed.

## Tasks

1. **Criteria:** go through "Acceptance S0007" in `work_items/phase3/README.md` point by point, with the evidence in the result.
2. **Every core element editable:** a headless test opens each element of the core set, changes it, saves it, and checks the file and a run with the new parameters.
3. **Manual check 11** (new section in `doc/MANUAL-CHECKS.md` with VS Code tasks): the owner configures elements of the imported v1 flows at 100 % and 225 % (every field type of the core set, the content types, the MIGRATION places, the expression check, the help in each of the three viewers (E0099), the window assistant of the hotkey trigger), the flow settings, and the window of an unhandled error; the owner also runs the `gui` tests of S0007.
4. **Documents:** REQUIREMENTS (every requirement of S0007 with `v2`, `Plan`, `Evidence`), ELEMENT-API-V2, PROTOCOL, ARCHITECTURE 8, MIGRATION (M-0064 back), MANUAL-CHECKS, `.vscode/tasks.json`; `python tools/doc_index.py --check`.
5. **Retrospective:** what was hard (HOW-TO entries), and what S0008 needs: the field types and assistants that the remaining elements use, and the list of help pages of WI-0112.
6. **Runs:** serial, parallel, `-m stress`, foundation and slow green.

## Acceptance criteria

- Every point of the S0007 acceptance has its evidence; the owner closed manual check 11.

## Not part of this

Detailing S0008 (its own session with the owner).
