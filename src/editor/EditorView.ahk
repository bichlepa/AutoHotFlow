#Requires AutoHotkey v2.0
#Include FlowRect.ahk

; The view of an editor (WI-0084, REQ-EDT-030, REQ-USE-090): zoom, offset in flow units and the DPI of the window, and
; the conversion between flow and canvas coordinates. Immutable: a change (zoom, move, resize) returns a new view.
;
; The scale of the drawing is zoom × DPI / 96, so a flow element has the same physical size on every screen
; (REQ-USE-090). The offset is the flow point at the top left corner of the canvas, as in v1 (flowSettings.Offsetx and
; Offsety). The zoom limits and the step (1.1) are those of v1 (Editor GUI User Input.ahk, mouse_wheel).
class EditorView {
    static ZOOM_MIN := 0.1
    static ZOOM_MAX := 3
    static ZOOM_STEP := 1.1
    static DEFAULT_ZOOM := 0.7
    static DEFAULT_OFFSET := -200
    static BASE_DPI := 96

    ; width and height: size of the canvas in pixels (0 when not known yet).
    __New(zoom := 0.7, offsetX := -200, offsetY := -200, dpi := 96, width := 0, height := 0) {
        this.Zoom := EditorView.ClampZoom(zoom)
        this.OffsetX := offsetX
        this.OffsetY := offsetY
        this.Dpi := dpi
        this.Width := width
        this.Height := height
    }

    ; Pixels per flow unit.
    Scale => this.Zoom * this.Dpi / EditorView.BASE_DPI

    ; Canvas pixel of a flow point: [x, y].
    ToCanvas(fx, fy) {
        s := this.Scale
        return [(fx - this.OffsetX) * s, (fy - this.OffsetY) * s]
    }

    ; Flow point of a canvas pixel: [x, y].
    ToFlow(cx, cy) {
        s := this.Scale
        return [this.OffsetX + cx / s, this.OffsetY + cy / s]
    }

    ; The flow rectangle that the canvas shows (the culling of the drawing uses it).
    VisibleArea() {
        s := this.Scale
        return FlowRect(this.OffsetX, this.OffsetY, this.Width / s, this.Height / s)
    }

    ; One wheel step at the canvas pixel (cx, cy): direction 1 zooms in, -1 zooms out. The flow point under the pixel
    ; stays under it (v1 mouse_wheel). At a limit the zoom stops there, the point still stays.
    ZoomStep(direction, cx, cy) {
        newZoom := EditorView.ClampZoom(direction > 0 ? this.Zoom * EditorView.ZOOM_STEP
            : this.Zoom / EditorView.ZOOM_STEP)
        under := this.ToFlow(cx, cy)
        s := newZoom * this.Dpi / EditorView.BASE_DPI
        return EditorView(newZoom, under[1] - cx / s, under[2] - cy / s, this.Dpi, this.Width, this.Height)
    }

    ; The view moved by a pixel delta (dragging): the content follows the pointer.
    Moved(dxPixels, dyPixels) {
        s := this.Scale
        return EditorView(this.Zoom, this.OffsetX - dxPixels / s, this.OffsetY - dyPixels / s, this.Dpi,
            this.Width, this.Height)
    }

    ; The same view on a canvas of another size or with another DPI.
    Resized(width, height, dpi := "") {
        return EditorView(this.Zoom, this.OffsetX, this.OffsetY, (dpi = "") ? this.Dpi : dpi, width, height)
    }

    ; The view of a flow from its flowSettings (keys zoomFactor, Offsetx and Offsety as v1 writes them, texts like
    ; "0.700000"). A missing or non-numeric value takes the default, as v1 Load.ahk does.
    static FromFlowSettings(settings, dpi := 96, width := 0, height := 0) {
        zoom := EditorView.DEFAULT_ZOOM, ox := EditorView.DEFAULT_OFFSET, oy := EditorView.DEFAULT_OFFSET
        if (settings is Map) {
            if (IsNumber(settings.Get("zoomFactor", "")))
                zoom := settings["zoomFactor"] + 0
            if (IsNumber(settings.Get("Offsetx", "")))
                ox := settings["Offsetx"] + 0
            if (IsNumber(settings.Get("Offsety", "")))
                oy := settings["Offsety"] + 0
        }
        return EditorView(zoom, ox, oy, dpi, width, height)
    }

    static ClampZoom(zoom) => Min(Max(zoom, EditorView.ZOOM_MIN), EditorView.ZOOM_MAX)
}
