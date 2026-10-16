# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

- **Tooltip as a worker element (WI-0056).** `Action_Tooltip` runs in the worker with a timer that removes it; it holds no pool slot. Consequence: a flow stop no longer removes the tooltip, only its time or a worker crash does (M-0065). Alternative: hold the slot for the tooltip's duration. Please confirm or choose the alternative.
- **Values of `A_UserAction` (WI-0056).** The debug and message dialogs set lower-case values (`ok`, `close`, `yes`, ...). The v1 values are upper-case. AHK `=` ignores case, so v1 flows should not break; please confirm this spelling (M-0067).

## Manual checks

- **DPI check of the dialog windows (REQ-USE-090).** The windows set per-monitor DPI awareness on their thread; the sizes are fixed pixel values and this is untested. Please run the check at 100 %, 125 % and 150 % once the guide is in `doc/MANUAL-CHECKS.md` (section 3, being written now).

## To know

- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, then passed three times. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **F-0097 (nested list loops copy the outer snapshot):** option A decided; the fix is due, because WI-0055 touched the same stack.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675), not reproduced. Open until a seed of that failure is found.
- **F-0089, F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
