# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8).

## Decisions

- **`Loop_Condition` sets `A_Index` before the first check (M-0059).** v1 set the index only after the check. The port follows the help text (`a_index <= 10` makes 10 passes). Please check this and confirm, or ask for the v1 order.
- **Question on F-0098 (fast loops flood the flow topic).** Your answer "Option B" with the reason "negligible, a change would break other parts that expect both messages" is recorded as: both events stay, no change (`accepted`). My option B was different (a separate count topic for subscribers that need only counts). Please confirm that "keep both events" is what you meant, or tell me the option you want.

## To know

- **F-0097 (nested list loops copy the outer snapshot): option A decided.** Share the hidden snapshot between the levels of the loop stack. The fix is scheduled after WI-0055 (flow control), because both touch the loop stack.
- **F-0096: the 0.25 s tolerance in the crash-lag test is kept** (your decision 3). Recorded in `doc/MIGRATION.md` as M-0062, a test-only deviation.
- **WI-0054 (loops)** is integrated and verified (`be5c088` to `2467349`).
- **WI-0059 (test admission, load figures, run history)** is done and integrated; see `work_items/phase3/STATUS.md`.
- **WI-0055 (flow control)** is running. Its questions will follow in its report. WI-0056 (dialogs) is next.
- **F-0089 is still open:** three fault tests that fail only under load. The supervisor fix for the kill case (F-0071) is verified and stays open until repeated slow runs are clean.
