# WI-0127 Screen and images

Size: L · Depends on: WI-0117 · Blocks: WI-0135

## Goal

The screenshot, pixel, image search and screen settings elements of v1 exist in v2, as workers. They use one GDI+ wrapper with the editor. Changing the screen settings goes through `SystemOps` (E0103). Requirements: REQ-ELM-350.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Screenshot` | worker | the whole screen, a monitor, a window, an area; file formats of v1; GDI+ |
| `Action_Get_Pixel_Color` | worker | `PixelGetColor`, coordinate modes, the colour assistant |
| `Action_Search_pixel` | worker | `PixelSearch`, variation |
| `Action_Search_Image` | worker | `ImageSearch` with the options of v1 |
| `Action_Get_Screen_Settings` | worker | monitors, resolution, colour depth, frequency, orientation (v1 `Class_Monitor`) |
| `Action_Set_Screen_Settings` | worker | `SystemOps` |

## Read first

The common part of the element packages (README S0008); `src/editor/render/Gdip*.ahk` and `doc/DECISIONS.md` E0085; `doc/ARCHITECTURE.md` 8; `doc/howto/` entries on DPI and GDI+; v1: `v1/Lib/GDI+/`, the monitor class the v1 elements include; AutoHotkey docs: `PixelGetColor`, `PixelSearch`, `ImageSearch`, `MonitorGet`, `CoordMode`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **One GDI+ wrapper:** move the editor's wrapper to a place that worker elements may include (rule `include-roles`), or show why it cannot be shared and write a small one in `lib/`; update ARCHITECTURE 8 and the test groups. The editor's tests stay green.
2. **DPI and several monitors:** coordinates of the screenshot and the searches on a monitor with another scale; write what was checked and what not.
3. **Tests:** screenshot of an own test window (compare a known pixel); pixel and image search on a known image shown in an own test window; the screen settings through the test provider.

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

Text recognition (OCR).

## Result

Status 2026-11-02: the six classes are ported; the selected full run is not green (xdist crash, see below).

**Commits (branch wip/wi0127):** 51ca7283 (GDI+ wrapper to `src/gdip/`), a8a1376d (SaveFile, CaptureScreen, CaptureWindow), 43d35956 (seam: MonitorCount, MonitorGetSetting, MonitorSetSetting; MonitorDdc), c0c530b3 (six elements, ScreenOps, help, MIGRATION M-0169 to M-0175, tests), 38c66894 (REQ-ELM-350, HOW-TO, OPEN-ITEMS F-9000* to F-9003*).

**Tests:**
- `tests/integration/test_screen_elements.py`: 18 passed (run 20261102-113550-3840, commit before c0c530b3, same code).
- `tests/ahk/gdip.test.ahk`: 21 passed; `tests/ahk/element_system_ops.test.ahk`: 4 passed.
- Schema, help, group table, architecture, doc index: 93 passed (direct runs).
- `tests/test_ahk_runner.py` at the v2-port tip in a fresh worktree (run 20261102-120311-1961b36f): 1170 passed, 1 skipped. On the branch: 1172 passed, 1 skipped (run without the rest of the selection).
- Selected run `python -m pytest tests -q --changed-from v2-port` on 38c66894 and on earlier states (four attempts): aborts with an xdist INTERNALERROR; the worker that runs `test_ahk_file_completes[json.test.ahk]` dies, so no tests report. Cause not found; not a permission issue. The same file passes alone and in its own selection, and at the v2-port tip. Treated as a harness problem (OPEN-ITEMS F-9002*).

**Decisions:** worker mode for pixel and image search; per-monitor DPI in the screen elements only; the seam uses monitor functions (DDC/CI) instead of the reserved ChangeDisplaySettings; Parameters() reads the monitor count without the seam; empty output names are skipped. The DDC question (resolution and similar not in v1) is `decision needed` (F-9000*).

**Not done or not checked:** the multi-monitor and several-scale behaviour; the real DDC writes (probe read only); the owner's manual checks of the screen elements (F-9003*); the Search image help page was read (its remarks are v2-accurate) but only the Screenshot, pixel and settings pages were corrected.

