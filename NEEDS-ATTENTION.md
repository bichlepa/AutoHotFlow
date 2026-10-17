# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

- **How the hotkey input tests send keys (WI-0064, escalated by the agent).** The spike did not settle it: unassigned keys fired in three of four runs (one run missed both hook keys, cause unknown). A real `Trigger_Hotkey` registration of an unassigned key did not fire on `SendInput` in one run, while calling its callback directly does fire. The input desktop then closed (the PC locked) and `SendInput` returned 0. Two questions for you: (1) which key-delivery method the input tests use (a hook-only probe, another unassigned key set, or the `gui` tier only); (2) whether these tests may run on this PC at all, given that they cannot run while it is locked. Until you decide, the tests skip with a reason. The uncommitted test files are in the workspace `wi-0064`.

## To know

- **Default limits of the runaway guard are accepted (owner, 2026-10-17):** 50,000 executions per minute, 100 waiting and 100 parallel instances (WI-0066; measurements MS-0036 and MS-0037). The owner also said the guard was designed too strictly; since the defaults are accepted, that point is moot and nothing was changed.

## Manual checks

- **Manual checks 4 and 5 (WI-0067, `doc/MANUAL-CHECKS.md`):** done by the owner on 2026-10-17, all steps pass (run record in the document). The first attempt failed because the Start tasks did not start the triggerhost; fixed.
- **Real-key tests (WI-0064, WI-0067):** the hotkey tests with real key presses and the `gui` tests of WI-0064 are waiting for the decision on how keys are delivered (see Decisions).

## To know

- **E0063 confirmed by the owner:** the enabled state of the triggers is kept per flow in `FlowStates/<flowId>.json`, not in one `FlowState.json` (WI-0068, integrated on `v2-port`, verified; stress test with 200 flows green). A read error now affects only its own flow. This closes the item about the read error of `FlowState.json` (WI-0060, decision 3).
- **WI-0060 (enabled state of triggers) is integrated** (commits `ff6448d`–`4bbe858` on `v2-port`). Reviewer approved without changes. Decisions taken by the author and accepted by the reviewer: `cmd.flow.enable`/`disable` without a following trigger answer `{ok:false, message}` and change nothing; new storage message `cmd.storage.flowstate.keepBroken` (storage renames a file the engine cannot parse); the engine does not wait for that answer before `ready`; writes come at most once per second. Note: the per-flow files of E0063 replace the single-file part of this.
- **Open point from the review:** a trigger removed by `cmd.flow.save` keeps its enabled entry in memory, so it comes back enabled if the editor adds it again with the same ID. Relevant for S0006, not tested.

## To know

- **Manual check 3 (DPI of the dialog windows) passed on 2026-10-16** (owner): at 100 % and 225 %, process started at either scale, DPI change with the window open, message box, debug dialog and tooltip. Not run: a second monitor with another scale (step 16; the owner moved a window between two monitors and saw the same as with a DPI change), and 125 % and 150 % in the final state. REQ-USE-090 is done for the dialogs only; manager, editor, tray icon and zoom remain open.
- **F-0101 (slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5), the same 145 to 164 as F-0092. It failed twice in a row and once alone, green since. Watch it in the test history.
- **Skipped test of the finding IDs:** `tests/test_open_items_ids.py` skips itself in a worktree, and `tools/verify.py` runs in one, so that check never runs during verification. Open for a small fix; not decided.
- **Dropped advice:** the documentation agent removed the HOW-TO entry about `--version`, including the advice to output `A_AhkVersion`. The rule stays in AGENTS.md.
