# WI-0058 Acceptance S0002

Size: S · Depends on: WI-0044 to WI-0057 · Blocks: S0003

## Goal

S0002 is demonstrably finished and the documents match the code. Afterwards S0003 is detailed.

## Tasks

1. **Checks:** the acceptance of S0002 in the README of this phase, point by point, with run IDs (smoke test, oracle, e2e, test corpus, measurements).
2. **Acceptance runs:** serial, parallel, `-m stress`, foundation (S0002 touches `src/Ahf*.ahk` and `tests/integration/helpers/`). Record the runtime of the full run and of the fast tier; if the fast tier has grown beyond its budget, propose a split.
3. **Documents:** `doc/ELEMENT-API-V2.md` (no open point of S0002 left in section 8), ARCHITECTURE (7, 8, 10: R0003 and R0004), PROTOCOL, MIGRATION, TEST-STRATEGY (7, 8, element tests, dialog tests), MEASUREMENTS, HOW-TO, CONVENTIONS, `AGENTS.md` (status), `work_items/phase3/STATUS.md`.
4. **Retrospective:** what did the estimate of the packages miss; how many of the v1 fixes of WI-0057 could a deterministic converter have made; what belongs in the scope of S0003. Briefly in the result.

## Acceptance criteria

All points of the acceptance of S0002 are met, or an open point is recorded in `doc/OPEN-ITEMS.md` with the agreement of the project owner.
