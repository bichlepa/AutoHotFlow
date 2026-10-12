# WI-43 Acceptance S1

Size: S · Depends on: WI-36 to WI-42 · Blocks: S2

## Goal

S1 is demonstrably finished, and the documents match the code. Afterwards S2 is detailed.

## Tasks

1. **Golden data:** all checked-in cases are equal or assigned to an "accepted deviation" class; private cases are local (only numbers in the report: count, equal, accepted, open).
2. **e2e:** A v1 flow with the test element is loaded from a v1 folder and converted, runs, and sets a variable of each kind; `global`/`static` are present after restarting the engine and after restarting the session; v2 has not written anything in the v1 data folder.
3. **Acceptance runs:** serial, parallel (rule from `doc/TEST-STRATEGY.md` after WI-34), `-m stress`. Record the new runtime of the full run.
4. **Documents:** `doc/AUSDRUECKE.md` complete (language, differences to AHK v2, differences to v1 and conversion, variables, built-in variables); ARCHITECTURE (4, 6.1, 6.3, 7, 8 `src/expr/`), PROTOCOL, ELEMENT-API, MIGRATION, TEST-STRATEGY, HOW-TO, `AGENTS.md` (status), `work_items/STATUS.md`, `work_items/HANDOVER.md`.
5. **Retrospective:** What did the estimate of the packages miss, what belongs in the scope of S2? Briefly in the result.

## Acceptance criteria

- All checkboxes for S1 in the README are set, runs are green.
- The project owner has seen the discrepancy catalog (WI-39) and the MIGRATION entries.
