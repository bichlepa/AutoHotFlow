# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Entries are removed when they are answered or done. An entry that is moved here leaves `doc/OPEN-ITEMS.md`, so it is maintained in one place only; its full text as it was is in the git history, commit `52f7923` (`git show 52f7923:doc/OPEN-ITEMS.md`). Last update: 2026-10-15, after the integration of the F-0078 rename (`7e046ff`), and the moving of F-0064 and F-0082 out of OPEN-ITEMS.

## Decisions

1. **Closing the debug window is reported as a crash (F-0064, moved here from OPEN-ITEMS).** How were the debug and manager windows closed in manual step 8 (X button, taskbar, tray)? Then choose: (a) hide the tray icons of the roles, (b) a clean exit when a role is closed from its window or tray, or (c) accept that an external close is reported as an unexpected end. Options and reasons: the full text of F-0064 in commit `52f7923`. The recommendation of the bug hunter is (b) or (c), not (a); `src/core/` needs your agreement either way.
2. **Missing package on load (WI-0047, M-0008).** A flow with an element of a package that is not installed loads and keeps the element (marked, it fails with `exception` when run). Should the manager ask the user whether to delete the element when the flow is opened? The decision is needed in S0004.
3. **Setting for the number of workers (F-0082, moved here from OPEN-ITEMS).** The setting is decided (E0044), but its form is open: pool size only, `workerLimit` only, or both, and the default. Needed before S0004 starts that part.
4. **Default working directory of flows (S0004).** v2 does not read `settings.json` yet. Decide whether `FlowWorkingDir` takes over the v1 default `A_MyDocuments\AutoHotFlow`. Its text was in `doc/OPEN-ITEMS.md`, "Open decisions", until commit `52f7923` (`git show 52f7923:doc/OPEN-ITEMS.md`).
5. **Acceptance S1 (WI-0043).** The work item stays open: the stress test with 200 big flows was red (F-0073), and the decision was to schedule the load time as a later optimization (E0042). Close S1 as done, or name what must still be shown.
6. **Manual check of the GUI.** The stub and the debug window still need your hand check, using the guides in `doc/MANUAL-CHECKS.md`. The phase 2 checkbox for WI-0013 waits for it. (Moved here from the open decisions of OPEN-ITEMS.)

## To know

- **Lost log line under load (F-0088, F-0089).** The fast and slow tiers show a log line lost in a burst of 5000 lines, and three fault tests that fail only under load. A bug hunter is looking at the log path now. No decision needed yet.
