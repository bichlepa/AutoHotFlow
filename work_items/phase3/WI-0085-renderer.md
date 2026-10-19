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
