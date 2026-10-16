# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

None open. Tooltip and `A_UserAction` were decided by the owner (2026-10-16), see M-0065 and M-0067.

## Manual checks

- **DPI check of the dialog windows (REQ-USE-090): no start path yet.** The guide is in `doc/MANUAL-CHECKS.md` section 3 (16 steps, scales 100, 125 and 150 %). It cannot be run, because no flow in the test data shows a dialog element and no start task exists for one. Recommendation: a small manual-check flow with Message_Box, Confirmation_Dialog, the debug dialog and the tooltip, started by a `Start:` task through `tools/manual_check.py`. Please confirm, then it is a small work item.
- **Scope of the DPI section (to confirm):** the section says that the dialog-box rule (window class `#32770`) does not cover these GUI windows. Please confirm that wording.

## To know

- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, then passed three times. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **F-0097 (nested list loops copy the outer snapshot):** option A decided; the fix is due, because WI-0055 touched the same stack.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675), not reproduced. Open until a seed of that failure is found.
- **F-0089, F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
