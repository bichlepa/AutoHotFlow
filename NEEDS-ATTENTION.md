# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-19 (documentation review: the manual checks of S0004 are done and removed).

## Decisions

- **R0002 failed: how is the editor drawn (blocks WI-0085)?** The measurement of WI-0083 (MS-0044 in `doc/MEASUREMENTS.md`, one machine, run alone): 300 ms per frame at 1920x1080 with 300 elements fully visible, budget 16 ms. Biggest cost: icons (108 ms, GDI+ rescales the large icon files on every draw), names 53 ms, shapes 43 ms. Measured remedies: static layer with only the running elements on top 25 ms (15 ms with pre-scaled icons), a `BitBlt` of a cached layer 1.9 ms; but a rebuild of the layer costs about 114 to 300 ms on every change, zoom or pan. Options: (a) a separate render process (ARCHITECTURE 2.1, criterion A), (b) a static layer plus pre-scaled icon and name caches in the editor process, (c) accept the cost. Recommendation: (b), and (a) only if the rebuild while zooming is felt to be too slow. WI-0084, WI-0086 and WI-0087 go on meanwhile.

(Time of the fast tier: decided on 2026-10-19, E0089: no fixed budget; the test groups decide.)

## Manual checks

Nothing waits. The manual checks of S0004 (manager parts A to E, start with Windows and UAC, settings dialog) passed on 2026-10-19; the record is in `doc/MANUAL-CHECKS.md`. Not covered by that record, in case you want to look once: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German texts of the manager (`assets/language/manager/de.ini`), which no agent has reviewed.

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **S0005 can stop for you:** WI-0083 measures R0002 (GDI+ drawing speed). If the measurement fails, it stops and asks you (`work_items/phase3/STATUS.md`). You accept the look of the renderer yourself (E0088, WI-0085).
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
