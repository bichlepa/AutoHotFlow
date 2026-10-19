# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-19 (documentation review: the manual checks of S0004 are done and removed).

## Decisions

- **Time of the fast tier (F-0144, `doc/OPEN-ITEMS.md`).** Your decision of 2026-10-16 (F-0108) wanted a fast tier of about 1 minute, up to 2 minutes at the end of the port. With about 1600 tests it takes 4 to 13 minutes on the development PC (run history, `python tools/test_history.py --last`). Decide: accept the new size (and change the rule in `AGENTS.md`), or move more tests into the slow tier.

## Manual checks

Nothing waits. The manual checks of S0004 (manager parts A to E, start with Windows and UAC, settings dialog) passed on 2026-10-19; the record is in `doc/MANUAL-CHECKS.md`. Not covered by that record, in case you want to look once: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German texts of the manager (`assets/language/manager/de.ini`), which no agent has reviewed.

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **S0005 can stop for you:** WI-0083 measures R0002 (GDI+ drawing speed). If the measurement fails, it stops and asks you (`work_items/phase3/STATUS.md`). You accept the look of the renderer yourself (E0088, WI-0085).
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
