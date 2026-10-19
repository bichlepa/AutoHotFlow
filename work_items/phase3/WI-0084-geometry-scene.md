# WI-0084 Geometry and scene (headless)

Size: M · Depends on: – · Blocks: WI-0085, WI-0088

## Goal

Pure computation, without GDI and without a window: where every element and every connection of a flow is drawn, as in v1, what lies under a point, and the immutable `Scene` that the renderer gets (ARCHITECTURE 2.1). The geometry is the base of the hit test that S0006 needs for selecting and moving. May start before WI-0082 (only new files).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 2.1, 7 (the keys of elements and connections), 8; `doc/CONVENTIONS.md`; `v1/Source_Draw/GDIp/GDIp.ahk` (`gdip_DrawEverything`: the anchor points of a connection, its five segments, the loop parts, the culling, `DrawResult`), `v1/Source_Common/Other/Design.ahk` (the sizes), `v1/Source_Editor/User Interface/Editor GUI User Input.ahk` (`mouse_wheel`: zoom at the mouse point); the example flows `tests/data/flows/v1_examples/`; `src/elements/base/ElementRegistry.ahk` (class lookup, `static Icon`).

## Tasks

1. **`FlowGeometry`** (`src/editor/`): the sizes of v1 as constants (element 140×105, grid 35, minimum connection height 15, zoom 0.1 to 3, default zoom 0.7 and offset −200); the parts of an element by kind (trigger, action, condition, loop with head, bar of width 1/8 and height `HeightOfVerticalBar`, foot of height 1/3 with the break field of width 1/4); the anchor points of a connection (`fromPart` HEAD or TAIL, `toPart` HEAD, BREAK or TAIL, an exception from a loop leaves at the foot) and its five segments exactly as v1 computes them (the v1 line numbers in the comments); the place of the label of a connection type other than `normal` and `exception`; the bounding box of a flow; culling against the visible area.
2. **Hit test:** a point in flow coordinates gives the element and its part, or the connection and its segment (v1's margin of 20 around a segment), elements before connections. Used by the tooltip (WI-0090) and by S0006.
3. **View math** (`EditorView` or part of the geometry): flow ↔ canvas coordinates with zoom, offset and the DPI scale (scale = zoom × DPI/96, so a flow has the same physical size on every screen, REQ-USE-090); zoom by a wheel step at a point (factor 1.1, the point stays under the mouse, the limits of v1); moving by a pixel delta.
4. **`Scene` and `SceneBuilder`:** from the definition (elements and connections; the kind from `type`; the icon and the display name of the class through the element registry of the editor process, which has all classes, E0041; an unknown class or a missing package gives a placeholder with its reason, REQ-MIG-070), the run states, the trigger states (enabled, armed, message), the MIGRATION places (`migration` key), the warnings, the view and the hovered item, an immutable scene: new arrays and maps, no reference into the model. A version number tells the window whether a new frame is needed.
5. **Unit tests** `tests/ahk/editor_geometry.test.ahk` and `tests/ahk/editor_scene.test.ahk`: the five segments for target below, above, left and right, from a loop head and foot, to a loop break, compared with values computed by hand from the v1 formulas; hit tests on every part and near a segment; zoom at a point keeps the point; a v1 example flow builds a scene with all its elements and connections; an unknown class becomes a placeholder.

## Acceptance criteria

- The unit tests are green; `python tools/arch_check.py` is green; the new files are in the group table.

## Not part of this

Drawing (WI-0085), the window and input (WI-0088, WI-0090).
