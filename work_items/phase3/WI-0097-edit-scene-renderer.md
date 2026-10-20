# WI-0097 Scene and renderer for editing: selection, buttons, new-element fields, drag layer

Size: M · Depends on: – · Blocks: WI-0098

## Goal

The editor can draw everything that the editing actions show, and it draws it fast enough to drag smoothly in a big flow. Requirements: REQ-EDT-020 (the look while editing), REQ-EDT-060 (the look).

## Read first

`AGENTS.md`; `doc/ARCHITECTURE.md` 2.1; `doc/DECISIONS.md` E0088, E0090; `doc/MEASUREMENTS.md` MS-0046, MS-0048; `doc/howto/drawing-gdip.md`; `src/editor/SceneBuilder.ahk`, `Scene.ahk`, `FlowGeometry.ahk`, `FlowHitTest.ahk`, `render/Renderer.ahk`, `render/EditorStyle.ahk`; v1: `v1/Source_Draw/GDIp/GDIp.ahk` (selection, buttons, the fields for new elements), `v1/Source_Common/Other/Design.ahk`, `v1/Icons/` (Plus, Edit, Trash, Move).

## Tasks

1. **Scene:** the selection (IDs). The buttons of the selected element or connection, as in v1: plus, a second plus for the tail of a loop, edit and trash; move 1 and move 2 for the ends of a connection; the switch and the star of the triggers are already drawn. The four fields for new elements at the top left (fixed to the canvas, not to the flow). A connection being drawn (from a part of an element to a point). The selection rectangle (E0094). The set that is being dragged (IDs and offset).
2. **Geometry and hit test:** the buttons and fields at the positions of v1 (`default_SizeOfButtons`). The hit order of v1: buttons, fields, elements (with the click-through priority of v1 for elements that overlap), connections. Unit tests.
3. **Renderer:** the selection and the buttons from `EditorStyle` (the icons into `assets/icons/`), drawn as an overlay above the cached layers. At the start of a drag, a static layer without the dragged elements and their connections is built once; they are then drawn live above it. v1 snapped to the grid only at the drop, so there is no snap preview.
4. **Look:** extend the screenshot tool of S0005 (a selected element, a selected connection with its buttons, a drag, the fields). The owner accepts the look, as in E0088.
5. **Measurement** (headless, `doc/MEASUREMENTS.md`): the frame during a drag of 1 and of 30 elements in the flow of 300 elements at 1920 × 1080 (budget: below 16 ms on average), the rebuild at the start of the drag and after the drop.
6. **Tests:** pixel probes for the selection, the buttons, the fields, the rectangle and the drag (headless, as in WI-0085).

## Acceptance criteria

- The tests of task 6 are green and the measurement is recorded. The owner accepted the screenshots. REQ-EDT-020 is updated.

## Not part of this

The input that uses them (WI-0098 to WI-0102).
