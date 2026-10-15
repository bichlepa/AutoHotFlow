# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-15, after the owner's decisions of the same day.

## Decisions

Other decisions of 2026-10-15 are in `doc/DECISIONS.md` (E0046 to E0051).

## Decisions

- **Protocol extension: `ready` in the answer of `cmd.engine.snapshot` (F-0090, commit 1ca4916).** The answer now says whether the engine has finished its start (flows and variables loaded, `evt.engine.ready` sent). It is an additive field; the tests use it because a client that subscribes late can miss `evt.engine.ready`. The alternative was a test-only fix without a reliable signal. Please confirm (or ask for the alternative). Text: `doc/PROTOCOL.md`.
- **Test admission and run history (WI-0059).** Implementer running; its result comes back with a spike first. Its open questions (defaults, names, the rule "no automatic rerun") are for you when the report arrives.

## To know

- **Lost log line under load (F-0088 closed 2026-10-15, F-0089 open).** F-0088 is fixed and verified (`doc/CLOSED-ITEMS.md`). F-0089 (three fault tests that fail only under load) is still open and not analysed.
- **Integration of `wip/requirements`** was done on 2026-10-15 (19 commits, rebased, index regenerated).
