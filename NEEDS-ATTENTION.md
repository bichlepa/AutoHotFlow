# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-17.

## Decisions

None open.

## Manual checks

None open.

## To know

- **Manual check 3 is only partly done** (2026-10-16, owner): at 100 % and 225 % the dialogs were checked. Not run: a second monitor with another scale, and 125 % and 150 %. Manager, editor, tray icon and zoom are still open (S0004, S0006).
- **Open point for S0006:** a trigger removed by `cmd.flow.save` keeps its enabled entry in memory, so it comes back enabled if the editor adds it again with the same ID. Not tested.
- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, green since. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
