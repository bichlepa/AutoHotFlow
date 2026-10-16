# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

- **Core set of S0002 (F-0107).** The README names 29 elements, the table lists 27. Is `Action_Sleep` part of the core set (it is already in the element files)? Please decide which number is right.
- **Fast tier budget (F-0108).** The fast tier takes about 91 s in parallel, the budget is about 45 s. Proposal: run the AHK cases of `test_ahk_runner` as one process per file, and move `test_core_e_dialogs` and the variable persistence fault test to the slow tier. Please approve, or name another split.
- **S0002 is not fully accepted yet.** WI-0058 is partly done: the retrospective (task 4) and the review of the documents besides ELEMENT-API section 8 (task 3) are missing. These go in after your two decisions above.

## Manual checks

- **DPI check of the dialog windows (REQ-USE-090): the owner is fixing the dialog DPI problem with a separate agent.** The check guide and start path stay as they are (`doc/MANUAL-CHECKS.md` section 3; task "Start: manual check 3").

## To know

- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, then passed three times. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **F-0097 (nested list loops copy the outer snapshot):** option A decided; the fix is due, because WI-0055 touched the same stack.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675), not reproduced. Open until a seed of that failure is found.
- **F-0089, F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
