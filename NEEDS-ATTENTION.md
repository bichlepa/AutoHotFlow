# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-15, after the owner's decisions of the same day.

## Decisions

Other decisions of 2026-10-15 are in `doc/DECISIONS.md` (E0046 to E0051).

- **F-0031 (hub connection deadlines vs. supervisor stalls): close as not a defect?** Analysed by reading and a regression test (`tests/ahk/pipe_write_gone.test.ahk`, commit 9b2d6eb). A late pump still delivers the frames of a gone peer before it reports `peer_closed`, so no data is lost. Options: (a) close as not a defect, the test stays as a regression test (recommended by the analysis); (b) apply the proposed shift anyway (not needed for any case found). Full text: `doc/OPEN-ITEMS.md`, entry F-0031.

## To know

- **Lost log line under load (F-0088 closed 2026-10-15, F-0089 open).** F-0088 is fixed and verified (`doc/CLOSED-ITEMS.md`). F-0089 (three fault tests that fail only under load) is still open and not analysed.
- **Integration of `wip/requirements`** was done on 2026-10-15 (19 commits, rebased, index regenerated).
