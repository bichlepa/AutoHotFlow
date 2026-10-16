# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

None open. The HOW-TO cleanup and the status-book notes were decided by a documentation agent (see the commits of `doc/howto/` and `doc/OPEN-ITEMS.md`).

## To know

- **F-0101 (new, slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, then passed three times. Watch it in the test history; no hunter round unless it returns.
- **Fast tier:** `tests/test_no_v1_dependency.py` was red on the base of the work branches; fixed on `v2-port` in `c27ff8f`. No `verify.py` green record yet on the current tip; the next `--auto` run covers all tiers.

- **F-0097 (nested list loops copy the outer snapshot):** option A decided (share the hidden snapshot between the levels of the loop stack). The fix is not done yet; it is now due, since WI-0055 touched the same stack and is integrated.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675, class F-0075), not reproduced by the verifier. Open until a seed of that failure is found.
- **F-0089 and F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
