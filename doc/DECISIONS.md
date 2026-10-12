# Decision Log

This file lists the binding decisions of the project owner for the AHK v2 port, with their IDs (E1, E2, ...). The IDs are stable: an ID is never reused or renumbered. A decision stays binding until a later entry supersedes it; the superseding entry names the ID it replaces. The "Superseded" section lists those cases.

Status words are taken from the sources. "Implemented" means that the source reports the change as done; it does not mean that this file re-checked it.

Where the detailed wording is in a repository document, the table names that document. Where it is only in the work-item files, the table gives the tag path `v2-phase2-final:work_items/...`. The tag `v2-phase2-final` is the last commit that still contained the work-item files (see `doc/HISTORY.md`).

## Decisions

| ID | Date | Decision | Effect on the code or docs | Details |
|---|---|---|---|---|
| E1 | 2026-10-11 | Changing a flow during execution is allowed (observable v1 behaviour). The engine uses the newest committed revision of a flow at every step. Long-term goal is a debugger: slow execution, pause at any time, breakpoints, single step, inspect and change variables while paused, edit the flow while debugging. The debugger is not built in phase 2b, but nothing may prevent it. | Implemented in WI-21. | `doc/ARCHITECTURE.md` 4.2 (semantics table) and 4.3 (debugger outlook); `v2-phase2-final:work_items/phase2b/README.md` |
| E2 | 2026-10-11 | The execution policy `wait` is implemented (M-11 confirmed). | Implemented in WI-21. | `doc/MIGRATION.md` M-11 |
| E3 | 2026-10-11 | Worker pool: the supervisor starts and stops worker processes on request of the engine (elastic pool). A worker that is running a job is exempt from the ping check. Deadlines for jobs are kept by the engine. | Implemented in WI-27. | `doc/ARCHITECTURE.md` 2.3 |
| E4 | 2026-10-11 | 64 bit only. 32-bit interpreters are not supported and are rejected at startup with exit code 2. | Decided in WI-20, implemented in WI-22. The entry point checks `A_PtrSize != 8`. | `doc/ARCHITECTURE.md` (header), `doc/PROTOCOL.md` (exit codes), `AGENTS.md` |
| E5 | 2026-10-11 | The idle CPU target (below 1 %) applies to the overall system. Measured 0.23 %. Target met, topic closed. | Measurement only (WI-20). | `doc/ARCHITECTURE.md` 9 |
| E6 | 2026-10-11 | The triggerhost (WI-14) is built early in phase 3, with the real triggers, not in phase 2b. | WI-14 is not built. Scheduled for phase 3. | `doc/ARCHITECTURE.md` 8 |
| E7 | 2026-10-11 | Deliberately deferred points are recorded in the watch list (observe or optimise later). | Watch list in `STATUS.md`. | `v2-phase2-final:work_items/STATUS.md`, section "Beobachtungsliste (E7)" |
| E8 | 2026-10-11 | Truth values go over the wire as real JSON booleans (`true`/`false`). The write format of flow files is unchanged in phase 2b. A format change is a separate decision for phase 3. Old flows and variables must load. | Implemented in WI-26. Rule in `doc/PROTOCOL.md` section 2 and an architecture rule (`wire-bool`). | `doc/ARCHITECTURE.md` 7 |
| E9 | 2026-10-12 | Deleting a flow has no deadline (`Executor.FlowDeleted`, confirmed). Running instances stop at once. Blocking workers are ended by the pool after `ORPHAN_MS`. | Implemented in WI-21. The command to delete a flow is missing (phase 3). | `doc/ARCHITECTURE.md` 4.2; `v2-phase2-final:work_items/phase2b/README.md`, "Nachtrag" |
| E10 | 2026-10-12 | Workers end with the engine. When the engine process ends (crash or normal end), the supervisor ends all living `worker:*` processes. A new engine builds its pool again. | Implemented in WI-33. Measured: a worker with a hanging job was gone 0.21 s after the engine died. | `doc/ARCHITECTURE.md` 6.2 and 6.4 |
| E11 | 2026-10-12 | The upper limit of the log buffer in the storage role (20000 entries or 8 MiB, WI-25) stays an internal constant, not a setting. | Documented in WI-32. | `v2-phase2-final:work_items/STATUS.md`, section "Entscheidungen Fix-Block" and "Bekannte Probleme" |
| E12 | 2026-10-12 | Finding F-16 is solved: all deadlines of the supervisor account for a stand-still of the supervisor, not only the heartbeat. | Implemented in WI-33. | `doc/ARCHITECTURE.md` 6.2 and 6.3 |
| E13 | 2026-10-12 | Confirmed: the changes F-05 and F-07 in `src/core/`, and MIGRATION M-11, M-17, M-18. | Documented in WI-32. | `doc/MIGRATION.md` |
| E14 | 2026-10-12 | Closing the manager window. In the stub this ends the whole application. The behaviour of the real manager is decided in phase 3. | None yet. The stub behaviour is unchanged. **Open** (see "Open"). | `v2-phase2-final:work_items/phase2b/README.md`, "Nachtrag"; `v2-phase2-final:work_items/HANDOVER.md`, "Offene Entscheidungen", item 1 |
| E15 | 2026-10-12 | An empty `--data=` (logs then go to `C:\Log`) is acceptable for now. Watch list entry, no fix. | None. | `v2-phase2-final:work_items/STATUS.md`, "Beobachtungsliste" |
| E16 | 2026-10-12 (date of the WI-34 addendum; no separate date in the source) | The change `Peer.CloseWhenFlushed` in `src/core/ipc/Peer.ahk` (made in WI-30, not in the package wording) is confirmed. | Code change in place since WI-30. | `doc/ARCHITECTURE.md` 6.3; `v2-phase2-final:work_items/phase2b/README.md`, "Nachtrag WI-34" |
| E17 | 2026-10-12 (date of the WI-34 addendum; no separate date in the source) | `scaled()` (`tests/support/timing.py`) with factor 3 in the parallel test run stays. The serial run (`-n 0`) and `-m stress` are the strict reference. They run at least at the end of every package that changes timing behaviour, and at the end of every block. | Rule in the test strategy. | `doc/TEST-STRATEGY.md` (timing section, "The parallel run is not the reference") |

## Open

| ID | Question | Status | Where it is tracked |
|---|---|---|---|
| E14 | What the real manager does when its window is closed (only close the window, minimise to tray, or end the application). | **Open.** Decided in phase 3. | `v2-phase2-final:work_items/HANDOVER.md`, "Offene Entscheidungen", item 1 |
| Phase 3 approval | Phase 3 is not started. It needs the explicit approval of the project owner, after the phase 3 plan has been drawn up together with Claude. | **Open.** The plan is a draft in `work_items/phase3/README.md`. | `work_items/phase3/README.md`; `v2-phase2-final:work_items/HANDOVER.md`, "Offene Entscheidungen", item 2 |

Not E-numbered, but still waiting for the project owner: finding F-43 (see the findings table in `v2-phase2-final:work_items/STATUS.md`, and `HANDOVER.md`, "Offene Punkte"). The sources also recommend closing F-36. That is a finding, not a decision entry.

## Superseded

None. No entry in the sources replaces another entry.

## Earlier decisions without ID

The Phase 0 and Phase 1 release by the project owner has nine items. The sources list them without IDs. They are numbered here only by position (item 1 to item 9) for reference. Source: `v2-phase2-final:work_items/STATUS.md`, section "Entscheidungen".

1. Several processes, one editor process per flow. Reason in `doc/ARCHITECTURE.md` 2.1.
2. Drawing happens in the editor process behind the `Renderer` interface, separable later. Risk not measured; measurement in phase 3.
3. Worker processes for blocking and AHK script elements.
4. Target version AHK v2.
5. Old flows and variables must load unchanged.
6. Own branch `v2-port`; temporary `v1/` folder.
7. The Chrome package is dropped.
8. Tests with pytest (end-to-end, fault injection, stress) plus AHK unit tests.
9. Direct port, no v1 fix branch.

## Notes on the sources

- E17 is worded differently in two places. `v2-phase2-final:work_items/phase2b/README.md` says the serial run and `-m stress` run "regelmäßig" (regularly). `v2-phase2-final:work_items/STATUS.md` and the test strategy give the rule above (end of each timing-relevant package and end of each block). This file uses the wording of the test strategy. Not checked: which wording the project owner meant.
- E16 appears under the same ID in every source that mentions it. No other numbering was found.
- `work_items/phase3/README.md` still says the plan is in `temp/phase3/` and will move after WI-34. The folder is `work_items/phase3/` now, and the fix block (WI-30 to WI-35) ran before phase 3. Stale text, not a decision.
