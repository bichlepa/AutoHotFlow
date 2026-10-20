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
