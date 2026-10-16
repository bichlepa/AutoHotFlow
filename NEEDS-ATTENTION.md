# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

- **Flow calls need the enabled state? (F-0099).** Until S0003 a trigger counts as enabled when its flow is enabled, and no flow is enabled after a start (the loader does not keep the state). Action_Execute_Flow with "This flow" (44 uses in the v1 flows) depends on it. Should the enabled state come from the flow file already now, or with S0003 (proposal: S0003, REQ-EXE-070)?
- **Result of a waiting call (WI-0055, decision 2).** The caller gets `exception` when the called instance had an unhandled exception or was stopped. Alternative: follow only the end reason. Please confirm.
- **Skip policy gives `exception` (WI-0055, decision 3).** A call that the policy `skip` refuses ends with `exception`, so the user sees that the flow did not run. Alternative: `normal`, as v1 did. Please confirm.

## To know

- **F-0097 (nested list loops copy the outer snapshot): option A decided.** Share the hidden snapshot between the levels of the loop stack. The fix is scheduled after WI-0055 (flow control), because both touch the loop stack.
- **F-0096: the 0.25 s tolerance in the crash-lag test is confirmed** (`eaac300`). Recorded in `doc/MIGRATION.md` as M-0062 (a test-only deviation), and as the one exception in the docstring of `tests/support/timing.py`.
- **F-0098: both events stay** (confirmed by the owner, 2026-10-16). Recorded as `accepted` in `doc/OPEN-ITEMS.md`.
- **WI-0054 (loops)** is integrated and verified (`be5c088` to `2467349`).
- **WI-0059 (test admission, load figures, run history)** is done and integrated; see `work_items/phase3/STATUS.md`.
- **WI-0055 (flow control)** is integrated and verified (`e4b368d` to `949afc2`); its questions are under Decisions. WI-0056 (dialogs) is next.
- **F-0089 is still open:** three fault tests that fail only under load. The supervisor fix for the kill case (F-0071) is verified and stays open until repeated slow runs are clean.
