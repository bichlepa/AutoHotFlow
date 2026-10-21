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
