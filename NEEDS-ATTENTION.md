# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-16 (session 8, wrap-up).

## Decisions

- **HOW-TO cleanup (owner decides; no entry is changed until then).** Candidates to merge or remove, from the split of `doc/howto/`:
  - syntax: "A space before `;` inside a string literal starts a comment" and "A semicolon after whitespace starts a comment even inside a string" (same fact).
  - Four entries on local variables or parameters named like functions or classes (syntax and tests).
  - "A static method used as a callback shifts the parameters" (syntax) and "A static class method is not a callback" (error handling).
  - "Truth values are the integers 1 and 0", "`Json.False` is true", "`Json.Parse` returns `true` as 1".
  - Three entries on overlapped pipe I/O (processes).
  - "Events before a subscription are lost..." and "A message sent only once does not reach a child that connects later".
  - "Re-entry: Pump, SendFrame and handlers interrupt each other" and "A re-entry lock makes pump first ineffective".
  - Two ctypes entries and three entries on test process output and `ahkrun.py` (tests).
  - "The AHK interpreter does not know --version" and "32-bit interpreter: check A_PtrSize" (both already rules in AGENTS.md).
  - Three entries on name clashes in classes (syntax, objects).
- **Notes that exist only in the status book.** `work_items/phase3/STATUS.md`, section "Recorded only here", has 11 notes that no other document holds. For each one: move it to its proper document (OPEN-ITEMS, MIGRATION, MANUAL-CHECKS), or drop it.

## To know

- **F-0101 (new, slow tier):** the storm smoke test saw the engine's handle count grow by 19 (limit 5). It failed twice in a row and once alone, then passed three times. Watch it in the test history; no hunter round unless it returns.
- **Fast tier:** `tests/test_no_v1_dependency.py` was red on the base of the work branches; fixed on `v2-port` in `c27ff8f`. No `verify.py` green record yet on the current tip; the next `--auto` run covers all tiers.

- **F-0097 (nested list loops copy the outer snapshot):** option A decided (share the hidden snapshot between the levels of the loop stack). The fix is not done yet; it is now due, since WI-0055 touched the same stack and is integrated.
- **F-0100 (random expression oracle run):** one failure in a slow run (seed 411675, class F-0075), not reproduced by the verifier. Open until a seed of that failure is found.
- **F-0089 and F-0084, F-0079, F-0086, F-0071:** load-dependent fault tests; open until repeated slow runs are clean.
