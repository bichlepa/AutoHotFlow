# WI-0082 Acceptance S0004

Size: M · Depends on: WI-0069 to WI-0081 · Blocks: S0005

## Goal

S0004 is demonstrably finished and the documents match the code. Afterwards S0005 is detailed.

## Tasks

1. **Criteria:** go through "Acceptance S0004" in `work_items/phase3/README.md` point by point, with the evidence (test, run ID, measurement, manual check) in the result.
2. **Memory (REQ-PRF-030, E0040):** private bytes of the background processes with the real manager open, with the manager window hidden and with no manager (start with Windows), one and three workers, the corpus of the memory test; in `doc/MEASUREMENTS.md`.
3. **Load path:** `tests/stress/test_big_flows.py` with the manager connected; time to ready, largest snapshot answer, time to the filled list.
4. **Manual checks:** the owner runs the manual check of block B (settings, language, about, log window, export and import, start with Windows, run as administrator) and the `gui` tests of S0004; the results in `doc/MANUAL-CHECKS.md`.
5. **Documents:** REQUIREMENTS (every requirement of S0004 with `v2`, `Plan`, `Evidence`), PROTOCOL, ARCHITECTURE 3, 6, 8, 9, MIGRATION, MANUAL-CHECKS, `.vscode/tasks.json`; `python tools/doc_index.py --check`.
6. **Retrospective:** what was hard in the UI roles (HOW-TO entries), what S0005 needs from `ui_common/` and the manager.
7. **Runs:** serial, parallel, `-m stress`, foundation and slow green.

## Acceptance criteria

- Every point of the S0004 acceptance has its evidence; the owner closed the manual checks.

## Not part of this

Detailing S0005 (own session with the owner).
