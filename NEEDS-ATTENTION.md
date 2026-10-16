# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

None open.

## Manual checks

None open.

## To know

- **Manual check 3 (DPI of the dialog windows) passed on 2026-10-16** (owner): at 100 % and 225 %, process started at either scale, DPI change with the window open, message box, debug dialog and tooltip. Not run: a second monitor with another scale (step 16; the owner moved a window between two monitors and saw the same as with a DPI change), and 125 % and 150 % in the final state. REQ-USE-090 is done for the dialogs only; manager, editor, tray icon and zoom remain open.
- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5), the same 145 to 164 as F-0092. It failed twice in a row and once alone, green since. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
