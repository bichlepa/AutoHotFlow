# Drawing with GDI+ (editor)

Entries for the drawing of the editor (`src/editor/render/`, `src/editor/Scene*.ahk`). Numbers are from `doc/MEASUREMENTS.md` (MS-0044, MS-0046 to MS-0048).

### A big icon file is scaled down on every draw

- **Problem:** The icon files of the Default package are large (`Sleep.ico` 201 × 232 px, `Bug.png` 195 × 259 px). Drawn at element size, GDI+ scales each one from its full size on every draw, so the icons alone cost 108 ms of a 300 ms frame (MS-0044).
- **Wrong:** Calling `DrawImage` with the source image and the box size on each frame.
- **Right:** Read the file once, keep a scaled copy per box size (`Renderer.ScaledIcon`, `GdipImage.Scaled`) and draw that copy. The cache is bounded (`Renderer.MAX_SCALED`); when it is full it is emptied, not evicted by entry.
- **Status:** verified (MS-0044 breakdown; the frame of the real renderer with the cache is 6.7 ms at 1920 × 1080, MS-0048).

### Every draw of a changing flow rebuilds the static layer only when needed

- **Problem:** Redrawing a flow of 300 elements from scratch costs about 300 ms per frame at 1920 × 1080 (MS-0044). A run state changes ten times a second and must not cost a full frame.
- **Wrong:** Rebuilding the scene and all draws for each state change.
- **Right:** The static content (shapes, icons, names, connections) is a cached layer that is rebuilt only when the flow, the zoom, the DPI or the pan out of the layer changes. The running elements are drawn on top of the layer each frame. A state change uses `Scene.WithStates` (4.6 ms mean for 60 changed elements, MS-0048) and not `SceneBuilder.Build` (about 21 ms, MS-0048).
- **Status:** verified (frame 6.7 ms and the states frame with the cached layer, MS-0048; the rebuild costs 113 ms at 1920 × 1080 and 182 ms at 3840 × 2160 in the same run).

### Text per call is the second largest cost

- **Problem:** Names took 53 ms of the 300 ms frame (MS-0044): font and string format were created for each name and label, as the v1 text routine does.
- **Wrong:** A GDI+ font and string format created inside the draw loop for every element.
- **Right:** Keep the font per size: `Renderer` caches it per size (the code of the font method, read in WI-0092). Do the same for the string format.
- **Status:** the cost is verified (MS-0044); the cache is verified by reading the code; the saving of the cache alone is not measured (not checked).

### A load error in an AHK comment looks like a clean run

- **Problem:** In a measurement script a comment started with `#` (AHK v1 style). AutoHotkey v2 reports `Illegal character in expression` at load time and writes it to stderr; the result file stayed empty. The command chain that ran four cases still ended with exit code 0, because the last command decided the exit code.
- **Wrong:** Trusting the exit code of a chain of `ahkrun.py` calls.
- **Right:** Use `;` for comments in AHK v2 and check that the result file has the expected lines (or the log of `ahkrun.py`) before taking numbers.
- **Status:** verified (WI-0092, `tests/ahk/helpers/renderer_bench.ahk`, first run).

### Text in a fixed box is cut off when the format does not wrap

- **Problem:** The four fields "Create new action" and so on are fixed boxes of 100 × 75 device pixels. At zoom 1.5 the labels were cut off after a few letters ("Create new acti").
- **Wrong:** A string format with wrapping off (`GdipFormat(1, 1, false, false)`, the format of the element badges) for a label that is wider than its box.
- **Right:** A format with wrapping on (`GdipFormat(1, 1, false, true)`) and a font size that fits two lines, so the label wraps inside the box.
- **Status:** verified (WI-0097, screenshots of `render_samples.ahk` at zoom 1.5, after the change the labels are complete).

### Pixel probes of the flow break when an overlay covers the top left of the canvas

- **Problem:** The fields for new elements are drawn at the top left of the canvas on every frame (as in v1). The tests of the renderer put the first element at the top left, so the probes read the fields, not the element. A test then passes for the wrong reason (the field is white, the probe expects the fill of an action, which is white too).
- **Wrong:** Keeping the test view at the offset that puts the flow's top left at the canvas corner.
- **Right:** Move the test view down so the flow starts below the overlay (`ViewAt` in `tests/ahk/editor_renderer.test.ahk`, offset -110), and probe the background at the far corner of the canvas, not at (2, 2).
- **Status:** verified (WI-0097: the pixel tests failed for the corner probe and for the loop at the bottom edge after the change, and pass after it).

### A drag keeps the static layer when the key leaves the dragged items out

- **Problem:** A drag moves elements every frame. If the layer key contained their positions, every frame of a drag would rebuild the layer (about 110 ms at 1920 × 1080, MS-0048).
- **Wrong:** Building the key of the whole scene, including the dragged elements at their moved positions.
- **Right:** `Renderer.StaticKey` skips the dragged elements and their connections (`Renderer.IsLive`), so the key of a drag does not change with its offset; the layer is built once at the start of the drag and once after the drop. Test: `CheckDraggedElementIsDrawnLive` counts the rebuilds.
- **Status:** verified (WI-0097, rebuild counts in the pixel test and in MS-0051: one rebuild at the start, one after the drop).

### A drag of 30 elements draws live at 25 ms per frame

- **Problem:** Drawing the dragged elements and their connections every frame costs about 20 ms for 30 elements at 1920 × 1080 (MS-0051), and 7 ms for 1 element. The frame budget is 16 ms.
- **Wrong:** Assuming a live draw of a moving group is cheap because the layer is cached.
- **Right:** Not decided. Options are in `doc/OPEN-ITEMS.md` (F-9000): a group layer for the dragged elements, or accepting it for big drags.
- **Status:** verified (MS-0051, one run); the split between elements and connections not checked.
