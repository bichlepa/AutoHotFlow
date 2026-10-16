# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8).

## Decisions

- **Nested list loops copy the outer snapshot (F-0097).** A loop inside a list loop copies the outer loop's snapshot at every entry. Measured: 500 / 1000 / 2000 members take 3.5 / 5.5 / 9.9 ms per outer pass, against about 0.5 ms without the inner loop. v1 behaved the same. Proposal: share one hidden snapshot between the levels of the loop stack. Options: (a) share the snapshot (recommended), (b) keep the copy and document the cost. Full text: `doc/OPEN-ITEMS.md`.
- **Fast loops flood the flow topic (F-0098).** A fast loop sends two `evt.element.state` events per pass to every subscriber. Relevant for the editor (S0005). Options: (a) coalesce the events of fast elements, (b) subscribers that only need counts subscribe to a count topic (recommended with the editor design). Full text: `doc/OPEN-ITEMS.md`.
- **`Loop_Condition` sets `A_Index` before the first check (M-0059).** v1 set the index only after the check, so the help text (`a_index <= 10` makes 10 passes) and v1 differed. The port follows the help text. Please confirm, or ask for the v1 order.

## To know

- **Test admission and run history (WI-0059) is done.** Integrated as `9cefa8c` to `1120c28` and `00a8816`. Your decisions are implemented: default `AHF_MAX_WORKERS` stays cores − 2 (fast tier on the idle machine: 44.7 s with 6 workers, 41.2 s with 8 before the change; 48.2 s and 41.0 s after); `-m "not stress"` is not exclusive any more; the job object only counts, with a psutil fallback recorded as `ownTree`; the tooling tests are split; recheck runs at the commit of the run. The synthetic-load test ran green on the idle machine (run 20261016-083827-7ec528a4). The last follow-up was integrated without a verifier, because verifiers were paused; the implementer ran the fast and foundation tiers itself (foundation run 20261016-084047-7ec528a4, 460 passed).
- **WI-0054 (loops) is integrated and verified** as `be5c088` to `2467349` (fast run 20261016-084656-24673497, foundation 20261016-084716-24673497, slow 20261016-084736-24673497, all green).
- **WI-0055 (flow control, the first work item with engine changes and a new protocol message) is running.** Its questions will follow in its report. WI-0056 (dialogs) is next.
- **F-0090 (persistence test) is not back on the current tip.** It failed twice under high external load in runs on an older base; all green runs on `2467349` (fast, foundation, slow) include it and pass. Still watched; see `work_items/phase3/STATUS.md`.
- **F-0089 is still open:** three fault tests that fail only under load. The supervisor fix for the kill case (F-0071) is verified and stays open until repeated slow runs are clean.
