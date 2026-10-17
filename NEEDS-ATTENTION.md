# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

None open.

## To know

- **Default limits of the runaway guard are accepted (owner, 2026-10-17):** 50,000 executions per minute, 100 waiting and 100 parallel instances (WI-0066; measurements MS-0036 and MS-0037). The owner also said the guard was designed too strictly; since the defaults are accepted, that point is moot and nothing was changed.

## Manual checks

- **Manual checks 4 and 5 (WI-0067, `doc/MANUAL-CHECKS.md`):** done by the owner on 2026-10-17, all steps pass (run record in the document). The first attempt failed because the Start tasks did not start the triggerhost; fixed.
- **Hotkey input tests (WI-0064, WI-0067):** solved on 2026-10-17. The normal-tier tests run (10 green, serial and parallel); the cause of the old skips was the choice of keys (plain hotkeys on `vk9A` to `vk9C` do not fire for `SendInput`), the PC lock was not the reason. Still for the owner: the `gui` tests with key combinations (VS Code task `Test: hotkey input with key combinations (gui...)`) and the hotkey part of REQ-TRG-010.

## To know

- **E0063 confirmed by the owner:** the enabled state of the triggers is kept per flow in `FlowStates/<flowId>.json`, not in one `FlowState.json` (WI-0068, integrated on `v2-port`, verified; stress test with 200 flows green). A read error now affects only its own flow. This closes the item about the read error of `FlowState.json` (WI-0060, decision 3).
- **WI-0060 (enabled state of triggers) is integrated** (commits `ff6448d`–`4bbe858` on `v2-port`). Reviewer approved without changes. Decisions taken by the author and accepted by the reviewer: `cmd.flow.enable`/`disable` without a following trigger answer `{ok:false, message}` and change nothing; new storage message `cmd.storage.flowstate.keepBroken` (storage renames a file the engine cannot parse); the engine does not wait for that answer before `ready`; writes come at most once per second. Note: the per-flow files of E0063 replace the single-file part of this.
- **Open point from the review:** a trigger removed by `cmd.flow.save` keeps its enabled entry in memory, so it comes back enabled if the editor adds it again with the same ID. Relevant for S0006, not tested.

## To know

- **Manual check 3 (DPI of the dialog windows) passed on 2026-10-16** (owner): at 100 % and 225 %, process started at either scale, DPI change with the window open, message box, debug dialog and tooltip. Not run: a second monitor with another scale (step 16; the owner moved a window between two monitors and saw the same as with a DPI change), and 125 % and 150 % in the final state. REQ-USE-090 is done for the dialogs only; manager, editor, tray icon and zoom remain open.
- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5), the same 145 to 164 as F-0092. It failed twice in a row and once alone, green since. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
