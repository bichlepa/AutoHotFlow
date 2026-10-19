# WI-0085 Renderer: draw the scene, style, icons

Size: M · Depends on: WI-0083 (and the owner's decision if R0002 failed), WI-0084 · Blocks: WI-0088

## Goal

`Renderer.Draw(scene, target)` draws a scene into a bitmap: the geometry of v1 with a modernized look (E0088), sharp at every zoom and scaling, flicker-free because it draws only into the back buffer. Requirements: REQ-EDT-020, REQ-PRF-060 (frame part), REQ-USE-090 (editor part).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 2.1, 8; `doc/CONVENTIONS.md`; WI-0083 and WI-0084 (results); `v1/Source_Draw/GDIp/GDIp.ahk` (what is drawn in which order); the screenshot `v1/Documentation/screenshots/Flow Editor.png`; `v1/Icons/`.

**Decision E0090 (R0002):** the frame is built from caches, see task 7. Start with haiku (owner, 2026-10-19: budget); escalate by the usual rule.

## Tasks

1. **Style** `EditorStyle` (one table, E0088): background, fill and border per kind, the colors of the states (running, recently run, exception, a disabled trigger, the selection for S0006), the connection pens (normal, exception, labels), the font (proposal: Segoe UI semibold instead of Arial bold, with ClearType-like text hint), the text size at zoom 1 (v1: 15), line widths. The geometry stays that of v1. Screenshots of two example flows (`tests/data/flows/v1_examples/`) at zoom 0.7 and 1.5 go to the owner, who accepts the look (E0088; the table can change later without code changes).
2. **Drawing order as v1:** background; grid dots above zoom 1; connections (the selected ones last); elements by kind (trigger rounded rectangle, action rectangle, condition diamond, loop with head, bar, foot and break field); per element the icon of its class, the name centered and clipped to the element, the trigger marks (switch on or off for the enabled state, star for the default manual trigger), the state overlays (running, recently run with a strength from 0 to 1 given by the scene, exception), a placeholder look for an unknown class or a missing package, a badge for warnings and MIGRATION places (filled in WI-0089). Everything outside the visible area is skipped.
3. **Icons:** the needed icons of v1 go to `assets/icons/` (also `enabled.ico`, `disabled.ico`, `running.ico` for WI-0091); element icons from `src/elements/<package>/Icons/`; a cache per process, loaded once and freed at the end. Reading them is reading program files (`arch-ok: file-io`, as the language files, ARCHITECTURE 4).
4. **Text:** size = text size × zoom × DPI/96; below a few pixels no text (only shapes), so a zoomed-out flow stays fast.
5. **Tests** (offscreen, normal tiers): pixel probes of a drawn scene: the background, the fill inside an element of each kind, a running element tinted, a pixel on a connection segment, a non-empty text area, a placeholder that differs from a normal element, the badge. The 300-element scene of WI-0083 drawn by the real renderer: the frame time is recorded (the budget is checked in WI-0092).
6. **Numbers for the role:** the renderer keeps the count of frames and the time of the last and the slowest frame, for the snapshot of the role (WI-0088).
7. **Caches (E0090):** a static layer (background, connections, elements without run state) in its own bitmap, rebuilt only when the scene, the zoom or the view change and drawn with one `BitBlt`; the run states and marks are drawn on top each frame; icons pre-scaled to the drawn size and cached; names cached per element (text bitmap or font and format objects); a layer larger than the window so that a pan does not rebuild. Measure with the bench of WI-0083: the frame with only states changing (target below 16 ms at 1920x1080, 300 elements) and the rebuild time; write both into MEASUREMENTS.md and the result. If the rebuild is above about 150 ms, say so for the owner.

8. **Draw order and hit order must agree (review of WI-0084):** the scene lists elements in Map order (sorted by ID text, not by creation) and the hit test lets the last drawn win; v1 additionally draws selected elements on top, which the scene does not model yet. The renderer draws in the scene order; if the order changes (selection on top), change the hit order with it (S0006).

## Acceptance criteria

- The tests of task 5 are green; `python tools/arch_check.py` is green.
- The owner accepted the look (screenshots in the result).
- The frame time of the 300-element scene is recorded.

## Not part of this

The window and the frame scheduling (WI-0088), the fading over time (WI-0089), the tooltip (WI-0090).

## Result

Code state: the renderer as committed in `ed1c9039` (the bench and the screenshot helper in `53d7058d`). Commits: `d5971cdc` (GDI+ wrapper), `bcffb12c` (scene: drawn name, package, default trigger), `0deccc65` (icons in `assets/icons/`), `ed1c9039` (renderer, style, unit test), `53d7058d` (bench, screenshot helper, VS Code task), and the documentation commit after it.

- **Tasks 1 to 8: done as far as the code and the offscreen tests go.** The window (WI-0088), the fading (WI-0089) and the tooltip (WI-0090) are not part of it.
- **Task 8 (draw and hit order): checked by reading.** The renderer draws the scene order; `FlowHitTest` asks the last element first and the connections after the elements, so what is drawn last is hit first. A selection on top (S0006) must change both. Nothing changed here.
- **Task 3, icons:** element icons from `src/elements/<package>/Icons/`, read once, scaled once per drawn size (`GdipImage.Scaled`), freed by `Renderer.Destroy`. Switch, star and the state icons from `assets/icons/`.
- **Task 7, caches (E0090):** the static layer (background, grid dots above zoom 1, connections, elements with icons, names and badges) is rebuilt only when that content, the zoom, the DPI or the view leaving the layer changes. A run or trigger state is an overlay drawn over the layer each frame. The layer is the window plus 1/8 of its size on each side, so a pan inside it is one BitBlt with an offset. Names use one font and one format per size (shared, not one bitmap per element).

**Tests (verified, run directly through `tools/ahkrun.py`, AutoHotkey 2.0.30):**
- `tests/ahk/editor_renderer.test.ahk`: 17 of 17 (commit `ed1c9039`): pixel probes of the background, the fill of each kind, the break field, a running tint, a connection, a yes label, the name, the icon, a placeholder, a warning badge, the switch and the star; the rebuild counts (a state change: no rebuild; a pan inside the layer: no rebuild; a zoom, a rename, another DPI: rebuild).
- `tests/ahk/gdip.test.ahk`: 19 of 19 (commit `d5971cdc`), 6 of them new (clip, ellipse, region copy, scaled copy, PNG).
- `tests/ahk/editor_scene.test.ahk`: 14 of 14 (commit `bcffb12c`), one new case.
- `tests/test_groups.py`: 44 passed; `tools/arch_check.py`: 0 violations (commit `ed1c9039`).
- Fast tier and `verify.py --auto`: see the last paragraph of this section.

**Frame numbers (MS-0046, `doc/MEASUREMENTS.md`; the bench `tests/ahk/helpers/renderer_bench.ahk`, run alone on one machine, CPU load 8 % before the start, one run per case; no pytest run ID):**

| Case | Frame with only the run states changing: mean (p95, max) | Layer rebuild: mean (max) |
|---|---|---|
| 1920×1080, whole flow, 300 elements, 350 connections, 30 running | **6.30 ms** (7.00, 8.40) | 106.5 ms (108.8) |
| 1920×1080, zoom 1, part of the flow | 3.97 ms (4.60, 6.34) | 65.4 ms (74.2) |
| 3840×2160, whole flow | 11.82 ms (12.94, 15.34) | **151.8 ms** (154.2): above about 150 ms, flagged for the owner (F-9001) |

The frame of the 300-element scene is below 16 ms at 1920×1080. The build of the scene itself takes 18 ms per state change (F-9000). Memory of the layer: about 13 MB at 1920×1080, about 52 MB at 3840×2160 (arithmetic, not measured).

**Screenshots (for the owner, E0088; not committed, `temp/` is ignored):** `temp/wi0085-screenshots/` in this workspace, i.e. `C:\Users\bichl\Documents\git\AutoHotFlow-wt\wi-85\temp\wi0085-screenshots\`: the two v1 example flows `Flow 2052424815` and `Flow 806132298` at zoom 0.7 and 1.5, four PNG files of 23 to 31 KB. They are drawn offscreen by the real renderer (`tests/ahk/helpers/render_samples.ahk`, VS Code task "Tool: editor screenshots"). **The look is not accepted yet**: the owner decides (E0088). The look table (`src/editor/render/EditorStyle.ahk`) can change without code changes.

**Decisions taken here (for the owner's review):**
1. The text on an element is the name the user gave it (`name`, as v1 draws it); the class name is the fallback. The scene carried only the class name before (WI-0084); changed in `bcffb12c`.
2. The default manual trigger (star) is read from the trigger state key `default`. v2 flows have no such flag; the window has to pass it.
3. A numeric run state is a strength of the recently-run overlay; `recent` is full strength. The fading over time is WI-0089.
4. The badge is a dot in the top right corner for a warning (or a migration place); its content is WI-0089's.
5. Icons are drawn at full opacity (v1 draws them at 20 %); the look table holds the value.
6. The layer uses ClearType grid-fitted text (`SetTextHint(5)`); not checked on a screen.
7. The look values are a proposal: light grey background, pastel fills per kind, slate borders, Segoe UI Semibold 15 px at zoom 1 (E0088).

**Findings:** F-9000 (the scene build of 18 ms per state change), F-9001 (the 4K rebuild of 152 ms and the 52 MB layer, owner decision), F-9002 (the word "break" is a literal), F-9003 (the tint of a running element lies over a later overlapping element). Found in the code while working: the scene did not carry the drawn name (fixed, `bcffb12c`).

**Not checked:** the BitBlt to a window and the frame scheduling (WI-0088); the look on a screen and at other scalings; a flow with many more elements or with the icons of other packages (only `Default` has icons); a long name at a very small zoom; the memory of five editors; the state path from the engine to the screen (MS-0007).
