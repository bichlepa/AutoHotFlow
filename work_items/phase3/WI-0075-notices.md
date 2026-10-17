# WI-0075 Notices: tray and manager, limit stop, unhandled errors (part 1)

Size: M · Depends on: WI-0072, WI-0074 · Blocks: WI-0082

## Goal

Errors and warnings that have no window of their own reach the user without a blocking dialog (REQ-USE-030): as a tray notice of the supervisor and as a list in the manager. Sources in S0004: a flow stopped by the runaway guard (`evt.flow.limit`), an unhandled `exception` of a flow (REQ-USE-080 part 1, E0072: notice and mark of the flow until the user has looked at it), storage errors (`evt.storage.error`), a flow file that could not be loaded. Many notices in a short time give one. Requirements: REQ-USE-030, REQ-USE-080 (part 1), REQ-EXE-170 (notice).

## Read first

As WI-0074, plus PROTOCOL 4.3 (`evt.flow.limit`, `evt.instance.ended` with reason `exception`, `evt.storage.error`), 4.7 (`evt.ui.notice`); E0062, E0072; REQ-USE-030, REQ-USE-080 in `doc/REQUIREMENTS.md`; v1 behaviour of the error window (read in the v1 code which events show it).

## Tasks

1. **Docs first:** PROTOCOL 4.7: who sends `evt.ui.notice`, who receives it (topic, so that supervisor and manager both see it), the payload (`level`, `text` as a `Lang` key with arguments or a text, `flowId?`, `kind`), the throttling rule.
2. **Engine:** sends a notice for an unhandled `exception` of a flow (with the element and the message, not the variables, E0072), for a limit stop, and passes on storage errors that the user must know. Throttling per flow and kind (for example one notice per 10 s with the count); the rule is in PROTOCOL.
3. **Supervisor:** shows a notice as a tray notice (`TrayTip`), throttled as well, without blocking.
4. **Manager:** a list of the recent notices (in memory, the last n), the mark at the flow until the user selects it or opens the list; the mark of a flow stopped by a limit says which limit.
5. **Switches:** the global switch "notify unhandled errors" (the setting comes with WI-0077; until then on); the per-flow switch comes with the flow settings (S0007).
6. **Tests:** e2e: an unhandled exception gives one notice and the mark, a burst gives one notice with the count; a limit stop gives the notice with the limit; the supervisor received the notice (log line or test hook, no real tray notice needed in the normal tiers).

## Acceptance criteria

- The tests of task 6 are green, serial and parallel; foundation tier green (supervisor change).

## Not part of this

The window with the variables of the branch (S0007, E0072); hints (`later`).
