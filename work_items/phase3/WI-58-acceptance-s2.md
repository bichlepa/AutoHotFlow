# WI-58 Acceptance S2

Size: S · Depends on: WI-44 to WI-57 · Blocks: S3

## Goal

S2 is demonstrably finished and the documents match the code. Afterwards S3 is detailed.

## Tasks

1. **Checks:** the acceptance of S2 in the README of this phase, point by point, with run IDs (smoke test, oracle, e2e, test corpus, measurements).
2. **Acceptance runs:** serial, parallel, `-m stress`, foundation (S2 touches `src/Ahf*.ahk` and `tests/integration/helpers/`). Record the runtime of the full run and of the fast tier; if the fast tier has grown beyond its budget, propose a split.
3. **Documents:** `doc/ELEMENT-API-V2.md` (no open point of S2 left in section 8), ARCHITECTURE (7, 8, 10: R3 and R4), PROTOCOL, MIGRATION, TEST-STRATEGY (7, 8, element tests, dialog tests), MEASUREMENTS, HOW-TO, CONVENTIONS, `AGENTS.md` (status), `work_items/phase3/STATUS.md`.
4. **Retrospective:** what did the estimate of the packages miss; how many of the v1 fixes of WI-57 could a deterministic converter have made; what belongs in the scope of S3. Briefly in the result.

## Acceptance criteria

All points of the acceptance of S2 are met, or an open point is recorded in `doc/OPEN-ITEMS.md` with the agreement of the project owner.
