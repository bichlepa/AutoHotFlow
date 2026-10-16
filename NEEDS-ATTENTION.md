# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

None open.

## To know

- **F-0097 (nested list loops copy the outer snapshot):** option A decided (share the hidden snapshot between the levels of the loop stack). The fix is not done yet; it is now due, since WI-0055 touched the same stack and is integrated.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675, class F-0075), not reproduced by the verifier. Open until a seed of that failure is found.
- **F-0089 and F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
