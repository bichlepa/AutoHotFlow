# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

- **F-0012: may it close without a test for `_ElementStarted` and `_ElementStopped`?** Both count the running elements of the executor. They are guarded by `Critical` (commit `ad6ac7d`, verified by reading only). The interruption cannot be forced in a test, and a spy on the counter would be the same pattern as the other fixes. Recommendation: accept them as guarded, and close F-0012 after one stress run of the engine (not yet done). Please answer yes or no.

## Manual checks

- **DPI check of the dialog windows (REQ-USE-090): ready to run.** Task "Start: manual check 3, dialog windows at other DPI scaling (manual_check.py)", or in a terminal: `python tools/manual_check.py start --flow dpi_dialogs -- --ui=stub --start=storage,engine,manager`. In the stub, press Start for the flow `dpi_dialogs`. Steps: `doc/MANUAL-CHECKS.md` section 3, at 100, 125 and 150 %. Closing the debug dialog with X ends the flow at that element; then start it again.
- **Confirm two choices of the check:** (1) you start the flow with the Start button; the tool does not start it. (2) No debug window in this check; only the dialogs are on the screen.

## To know

- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, then passed three times. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **F-0097 (nested list loops copy the outer snapshot):** option A decided; the fix is due, because WI-0055 touched the same stack.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675), not reproduced. Open until a seed of that failure is found.
- **F-0089, F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
