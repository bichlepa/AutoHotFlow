# Needs attention (project owner)

Kept by the orchestrator, see `doc/ORCHESTRATOR.md` section 11. Only what waits for the project owner: a decision, a manual check, or a fact the owner must know. Last update: 2026-10-19 (documentation review: the manual checks of S0004 are done and removed).

## Decisions

- **Look of the editor (E0088, WI-0085):** you accept the look of the renderer. Four screenshots of two v1 example flows (zoom 0.7 and 1.5) are in `temp/wi0085-screenshots/` of the main checkout (not committed). The values are a proposal in `src/editor/render/EditorStyle.ahk` (Segoe UI, state colors, icons at full opacity where v1 used 20 %). Say what to change, or accept it.
- **4K rebuild (F-0151):** the cache of E0090 gives 6.3 ms per frame of a state change (budget 16 ms). Rebuilding the static layer takes 106 ms at 1920x1080 and 152 ms at 3840x2160 (layer about 52 MB), on every change of the flow, zoom or a pan out of the margin. Options: accept it (recommended for now), a smaller margin, a rebuild in parts, or a render process. Not urgent.

(R0002: decided on 2026-10-19, E0090. Time of the fast tier: E0089.)

## Manual checks

Nothing waits. The manual checks of S0004 (manager parts A to E, start with Windows and UAC, settings dialog) passed on 2026-10-19; the record is in `doc/MANUAL-CHECKS.md`. Not covered by that record, in case you want to look once: whether v1 or 7-Zip opens an `.ahf` file written by v2 (F-0129), and the German texts of the manager (`assets/language/manager/de.ini`), which no agent has reviewed.

## To know

- **Decisions taken for you (WI-0081):** `Action_Execute_Flow` and `Action_Set_Flow_Status` count as acting on the system (the import warning lists them); `Action_Message_Box` and `Action_Tooltip` do not. The unpacked size of an `.ahf` is limited to 4 MB, UNC paths are refused (F-0132). Say so if you want it differently.
- **S0005:** you accept the look of the renderer yourself (E0088, WI-0085).
- **Stress tests:** run when a work item requires them (your permission of 2026-10-17). A stress run no longer opens the manager window (F-0143 fixed); the window variant needs `-m "stress or gui"`.
- **Slow tier:** relevant again (your decision of 2026-10-17); the verification of a state includes it.
