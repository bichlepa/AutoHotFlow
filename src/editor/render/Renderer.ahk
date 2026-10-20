#Requires AutoHotkey v2.0
#Include ..\..\core\AhfError.ahk
#Include Gdip.ahk
#Include GdipBrush.ahk
#Include GdipPen.ahk
#Include GdipFont.ahk
#Include GdipFormat.ahk
#Include GdipImage.ahk
#Include GdipCanvas.ahk
#Include EditorStyle.ahk
#Include ..\FlowRect.ahk
#Include ..\FlowGeometry.ahk

; Draws a Scene into a GdipCanvas (WI-0085, REQ-EDT-020, ARCHITECTURE 2.1, E0090). The window copies the target to the
; screen; the renderer never draws to a window.
;
; Frame (Draw): the static part of the flow (background, grid dots, connections, elements with their icons and names)
; is a cached layer, rebuilt only when the static content of the scene, the zoom or the DPI changes, or when the view
; leaves the layer. The layer is larger than the target (MARGIN on each side), so a pan is a copy with another offset.
; Each frame: one BitBlt of the layer, then the state overlays (running, exception, fading), the marks of the triggers
; (switch, star) and the badges (warning count, arming error; WI-0089), drawn on top. A state change therefore costs an
; overlay, not a rebuild. The badges come last, so that they stay readable on a running or fading element.
;
; The static content is compared with StaticKey: everything that is not a run state, a trigger state or a warning count.
; Those are copied into the scene and drawn over the layer.
;
; Order (as v1): background, grid dots (zoom above 1), connections (in scene order), elements (in scene order: the
; last one is on top, as FlowHitTest assumes), then the overlays and marks. A selection on top (S0006) changes the
; scene order and the hit order together.
;
; The renderer counts its frames and rebuilds (Snapshot) for the status of the editor role (WI-0088). Icons are read
; once from their files and kept until Destroy; scaled copies are kept per drawn size.
class Renderer {
    ; the layer is the target plus this share of its width and height on every side
    static MARGIN := 0.125
    static MAX_FONTS := 8
    static MAX_SCALED := 96
    static MAX_OVERLAYS := 32

    layer := ""
    layerKey := ""
    layerScale := 0
    layerDpi := 0
    layerLeft := 0
    layerTop := 0
    tools := ""
    toolsDpi := 0
    fonts := ""
    format := ""
    images := ""
    scaled := ""
    overlays := ""
    iconRoot := ""
    assetRoot := ""

    FramesDrawn := 0
    TotalFrameMs := 0
    LastFrameMs := 0
    SlowestFrameMs := 0
    Rebuilds := 0
    LastRebuildMs := 0

    ; iconRoot: the folder that holds the packages (src\elements). assetRoot: the folder of assets\icons.
    __New(iconRoot := "", assetRoot := "") {
        SplitPath(A_LineFile, , &here)
        this.iconRoot := (iconRoot = "") ? here "\..\..\elements" : iconRoot
        this.assetRoot := (assetRoot = "") ? here "\..\..\..\assets\icons" : assetRoot
        this.fonts := Map()
        this.images := Map()
        this.scaled := Map()
        this.overlays := Map()
    }

    ; Draws the scene into target (a GdipCanvas, the size of the window). Throws AhfError when GDI+ fails.
    Draw(scene, target) {
        t0 := Renderer.Now()
        W := target.width
        H := target.height
        if (W < 1 || H < 1)
            return
        view := scene.View
        s := view.Scale
        this.EnsureTools(view.Dpi)
        key := Renderer.StaticKey(scene)
        mX := Round(W * Renderer.MARGIN)
        mY := Round(H * Renderer.MARGIN)
        lw := W + 2 * mX
        lh := H + 2 * mY
        if (this.NeedsLayer(key, s, view.Dpi, lw, lh, view, W, H))
            this.BuildLayer(scene, view, key, lw, lh, mX, mY)
        sx := Round((view.OffsetX - this.layerLeft) * s)
        sy := Round((view.OffsetY - this.layerTop) * s)
        this.layer.CopyRegionTo(target, 0, 0, W, H, sx, sy)
        this.DrawStates(scene, target, view)
        this.DrawMarks(scene, target, view)
        this.DrawBadges(scene, target, view)
        ms := Renderer.Now() - t0
        this.FramesDrawn += 1
        this.TotalFrameMs += ms
        this.LastFrameMs := ms
        this.SlowestFrameMs := Max(this.SlowestFrameMs, ms)
    }

    ; Makes the next Draw rebuild the layer (the bench uses it to time a rebuild).
    Invalidate() {
        this.DropLayer()
    }

    ; The counters for the status of the role: frames, time of the last and the slowest frame, rebuilds.
    ; The times are whole milliseconds: the JSON of the snapshot keeps numbers as whole numbers (a float would be text).
    Snapshot() {
        mean := this.FramesDrawn ? this.TotalFrameMs / this.FramesDrawn : 0
        return Map("frames", this.FramesDrawn, "meanFrameMs", Round(mean), "lastFrameMs", Round(this.LastFrameMs)
            , "slowestFrameMs", Round(this.SlowestFrameMs), "rebuilds", this.Rebuilds
            , "lastRebuildMs", Round(this.LastRebuildMs))
    }

    ; Releases everything the renderer holds (GDI+ objects). Call it before Gdip.Shutdown.
    Destroy() {
        this.DropLayer()
        this.DestroyTools()
        this.DestroyMap(this.fonts)
        this.DestroyMap(this.images)
        this.DestroyMap(this.scaled)
        this.DestroyMap(this.overlays)
        if (this.format) {
            this.format.Destroy()
            this.format := ""
        }
    }

    ; The text of everything that does not change with a run state or a trigger state. Two scenes with the same key
    ; have the same layer.
    static StaticKey(scene) {
        key := ""
        for element in scene.Elements
            key .= element.Id "|" element.Kind "|" element.ClassName "|" element.Name "|" element.Icon "|"
                . element.Package "|" element.X "|" element.Y "|" element.HeightOfVerticalBar "|"
                . element.Placeholder "|" element.Migration.Length ";"
        for connection in scene.Connections
            key .= "c" connection.Id "|" connection.From "|" connection.To "|" connection.Type "|"
                . connection.FromPart "|" connection.ToPart "|" connection.StartX "|" connection.StartY "|"
                . connection.AimX "|" connection.AimY ";"
        return key
    }

    ; Seconds of the performance counter in milliseconds.
    static Now() {
        static freq := 0
        if (!freq)
            DllCall("QueryPerformanceFrequency", "Int64*", &freq)
        DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
        return t * 1000 / freq
    }

    NeedsLayer(key, s, dpi, lw, lh, view, W, H) {
        if (!this.layer)
            return true
        if (this.layer.width != lw || this.layer.height != lh)
            return true
        if (s != this.layerScale || dpi != this.layerDpi || key != this.layerKey)
            return true
        sx := Round((view.OffsetX - this.layerLeft) * s)
        sy := Round((view.OffsetY - this.layerTop) * s)
        return sx < 0 || sy < 0 || sx + W > lw || sy + H > lh
    }

    BuildLayer(scene, view, key, lw, lh, mX, mY) {
        t0 := Renderer.Now()
        s := view.Scale
        this.DropLayer()
        canvas := GdipCanvas(lw, lh)
        try {
            canvas.SetTextHint(5)                ; ClearType grid fitting: the layer is opaque
            this.layerLeft := view.OffsetX - mX / s
            this.layerTop := view.OffsetY - mY / s
            ox := this.layerLeft
            oy := this.layerTop
            canvas.Clear(EditorStyle.Background)
            visible := FlowRect(ox, oy, lw / s, lh / s)
            if (view.Zoom > 1)
                this.DrawGrid(canvas, ox, oy, s, lw, lh)
            for connection in scene.Connections {
                if (FlowGeometry.ConnectionVisible(connection.StartX, connection.StartY, connection.AimX,
                        connection.AimY, visible))
                    this.DrawConnection(canvas, connection, ox, oy, s)
            }
            for element in scene.Elements {
                if (FlowGeometry.ElementVisible(element.Bounds, visible))
                    this.DrawElement(canvas, element, ox, oy, s)
            }
        } catch as failure {
            canvas.Destroy()
            throw failure
        }
        this.layer := canvas
        this.layerKey := key
        this.layerScale := s
        this.layerDpi := view.Dpi
        this.Rebuilds += 1
        this.LastRebuildMs := Renderer.Now() - t0
    }

    DropLayer() {
        if (this.layer) {
            this.layer.Destroy()
            this.layer := ""
        }
        this.layerKey := ""
    }

    ; Dots on a grid of GridStep flow units, as v1 draws them above zoom 1.
    DrawGrid(canvas, ox, oy, s, lw, lh) {
        step := EditorStyle.GridStep
        d := EditorStyle.GridDotSize
        brush := this.tools["gridDot"]
        wx := Floor(ox / step) * step
        while (wx < ox + lw / s) {
            wy := Floor(oy / step) * step
            while (wy < oy + lh / s) {
                canvas.FillRect(brush, (wx - ox) * s - d / 2, (wy - oy) * s - d / 2, d, d)
                wy += step
            }
            wx += step
        }
    }

    ; One connection: its five segments in the pen of its type, and its label.
    DrawConnection(canvas, connection, ox, oy, s) {
        pen := (connection.Type = "exception") ? this.tools["exceptionLine"] : this.tools["line"]
        for segment in connection.Segments
            canvas.DrawLine(pen, (segment.X - ox) * s, (segment.Y - oy) * s, (segment.Right - ox) * s
                , (segment.Bottom - oy) * s)
        label := connection.Label
        if (!(label is Map))
            return
        size := EditorStyle.TextSize * EditorStyle.LabelTextFactor
        if (size * s < EditorStyle.MinTextPx)
            return
        rect := label["rect"]
        textFormat := (label["align"] = "right") ? this.tools["formatRight"] : this.tools["formatLeft"]
        canvas.DrawText(this.tools["labelText"], this.FontFor(size * s), textFormat, connection.Type
            , (rect.X - ox) * s, (rect.Y - oy) * s, rect.W * s, rect.H * s)
    }

    ; One element of the static layer: shape, icon, name, the badge of a warning or a migration place.
    DrawElement(canvas, element, ox, oy, s) {
        placeholder := (element.Placeholder != "")
        body := placeholder ? this.tools["placeholder"] : this.BodyBrush(element.Kind)
        pen := placeholder ? this.tools["placeholderLine"] : this.tools["border"]
        this.FillShape(canvas, body, element, ox, oy, s, placeholder ? body : this.tools["breakFill"])
        this.OutlineShape(canvas, pen, element, ox, oy, s)
        x := (element.X - ox) * s
        y := (element.Y - oy) * s
        w := FlowGeometry.ELEMENT_WIDTH * s
        h := FlowGeometry.ELEMENT_HEIGHT * s
        if (!placeholder && element.Icon != "")
            this.DrawIcon(canvas, element, x, y, w, h, s)
        if (element.Kind = "loop")
            this.DrawBreakWord(canvas, element, ox, oy, s)
        this.DrawName(canvas, element, x, y, w, h, s, placeholder ? this.tools["placeholderText"] : this.tools["text"])
    }

    ; The icon of the element's class, fitted into its box at the top of the element.
    DrawIcon(canvas, element, x, y, w, h, s) {
        box := EditorStyle.IconBox * s
        fit := this.ScaledIcon(this.IconPath(element.Package, element.Icon), box, box)
        if (!(fit is Array))
            return
        ix := x + (w - fit[2]) / 2
        iy := y + EditorStyle.IconTop * s + (box - fit[3]) / 2
        canvas.DrawImage(fit[1], ix, iy, fit[2], fit[3], EditorStyle.IconAlpha)
    }

    ; The name, centered and clipped to the element; no text when it is too small to read.
    DrawName(canvas, element, x, y, w, h, s, brush) {
        size := EditorStyle.TextSize * s
        if (size < EditorStyle.MinTextPx || element.Name = "")
            return
        inset := EditorStyle.NameInset * s
        top := EditorStyle.NameTop * s
        bottom := 4 * s
        canvas.SetClip(x, y, w, h)
        try
            canvas.DrawText(brush, this.FontFor(size), this.NameFormat(), element.Name, x + inset, y + top
                , w - 2 * inset, h - top - bottom)
        finally
            canvas.ResetClip()
    }

    ; The word "break" in the break field of a loop (the fourth part).
    DrawBreakWord(canvas, element, ox, oy, s) {
        size := EditorStyle.TextSize * EditorStyle.BreakTextFactor * s
        if (size < EditorStyle.MinTextPx || element.Parts.Length < 4)
            return
        part := element.Parts[4]
        canvas.DrawText(this.tools["breakText"], this.FontFor(size), this.tools["formatCenter"], "break"
            , (part.X - ox) * s, (part.Y - oy) * s, part.W * s, part.H * s)
    }

    ; The state overlays of the frame: running, exception and recently run elements and connections.
    DrawStates(scene, target, view) {
        s := view.Scale
        ox := view.OffsetX
        oy := view.OffsetY
        visible := view.VisibleArea()
        for connection in scene.Connections {
            if (connection.Run = "" || !FlowGeometry.ConnectionVisible(connection.StartX, connection.StartY
                    , connection.AimX, connection.AimY, visible))
                continue
            pen := IsNumber(connection.Run) ? this.ConnectionRunPen(connection.Run) : this.tools["runLine"]
            for segment in connection.Segments
                target.DrawLine(pen, (segment.X - ox) * s, (segment.Y - oy) * s
                    , (segment.Right - ox) * s, (segment.Bottom - oy) * s)
        }
        for element in scene.Elements {
            argb := Renderer.StateFill(element.Run)
            if (argb = "" || !FlowGeometry.ElementVisible(element.Bounds, visible))
                continue
            brush := this.OverlayBrush(argb)
            this.FillShape(target, brush, element, ox, oy, s, brush)
        }
    }

    ; The marks of the triggers, on top of the layer: the switch (on or off) and the star of the default trigger.
    DrawMarks(scene, target, view) {
        s := view.Scale
        ox := view.OffsetX
        oy := view.OffsetY
        visible := view.VisibleArea()
        size := EditorStyle.MarkSize * s
        for element in scene.Elements {
            if (element.Kind != "trigger" || !(element.Trigger is Map)
                    || !FlowGeometry.ElementVisible(element.Bounds, visible))
                continue
            x := (element.X - ox) * s
            y := (element.Y - oy) * s
            w := FlowGeometry.ELEMENT_WIDTH * s
            h := FlowGeometry.ELEMENT_HEIGHT * s
            switchIcon := element.Trigger["enabled"] ? EditorStyle.SwitchOn : EditorStyle.SwitchOff
            this.DrawMark(target, this.AssetPath(switchIcon), x + 0.8 * w, y + 0.25 * h, size)
            if (element.Trigger["default"])
                this.DrawMark(target, this.AssetPath(EditorStyle.StarFilled), x + 0.15 * w, y + 0.2 * h, size)
        }
    }

    ; A mark fitted into a box of size, centered at (cx, cy).
    DrawMark(canvas, path, cx, cy, size) {
        fit := this.ScaledIcon(path, size, size)
        if (fit is Array)
            canvas.DrawImage(fit[1], cx - fit[2] / 2, cy - fit[3] / 2, fit[2], fit[3])
    }

    ; The badges of the frame, drawn over the state overlays so that they stay readable on a running element: the
    ; migration place of an element (top right, WI-0085), its warning count (bottom right) and the arming error of a
    ; trigger (bottom left, WI-0089). All of them are drawn over the layer, so a new count costs no rebuild.
    DrawBadges(scene, target, view) {
        s := view.Scale
        ox := view.OffsetX
        oy := view.OffsetY
        visible := view.VisibleArea()
        r := EditorStyle.BadgeRadius * s
        for element in scene.Elements {
            failed := (element.Trigger is Map && element.Trigger["message"] != "")
            if ((element.Migration.Length = 0 && element.WarningCount = 0 && !failed)
                    || !FlowGeometry.ElementVisible(element.Bounds, visible))
                continue
            x := (element.X - ox) * s
            y := (element.Y - oy) * s
            w := FlowGeometry.ELEMENT_WIDTH * s
            h := FlowGeometry.ELEMENT_HEIGHT * s
            if (element.Migration.Length > 0)
                target.FillEllipse(this.tools["migration"], x + w - 12 * s - r, y + 12 * s - r, 2 * r, 2 * r)
            if (element.WarningCount > 0)
                this.DrawCountBadge(target, element.WarningCount, x + w - 12 * s, y + h - 12 * s, r, s)
            if (failed)
                target.FillEllipse(this.tools["error"], x + 12 * s - r, y + h - 12 * s - r, 2 * r, 2 * r)
        }
    }

    ; A warning badge with its count (99+ above that), centered at (cx, cy) with radius r.
    DrawCountBadge(canvas, count, cx, cy, r, s) {
        canvas.FillEllipse(this.tools["warning"], cx - r, cy - r, 2 * r, 2 * r)
        size := EditorStyle.BadgeTextSize * s
        if (size < EditorStyle.MinTextPx)
            return
        text := (count > 99) ? "99+" : String(count)
        canvas.DrawText(this.tools["badgeText"], this.FontFor(size), this.tools["formatCenter"], text
            , cx - r, cy - r, 2 * r, 2 * r)
    }

    ; The pen of a fading connection: the running line in one of 16 alpha steps (a fade is drawn in steps, so a pen is
    ; made once per step and not per frame).
    ConnectionRunPen(strength) {
        level := Round(Min(Max(strength, 0), 1) * 16)
        level := Max(level, 1)
        key := "runLine." level
        if (!this.tools.Has(key)) {
            alpha := Round(level * 255 / 16)
            argb := (alpha << 24) | (EditorStyle.RunningLineColor & 0xFFFFFF)
            this.tools[key] := GdipPen(argb, EditorStyle.RunningLineWidth * this.toolsDpi / 96)
        }
        return this.tools[key]
    }

    ; The fill of the state overlay (ARGB), or "" when the element has no state.
    static StateFill(state) {
        if (state = "")
            return ""
        if (state = "running")
            return EditorStyle.RunningFill
        if (state = "exception")
            return EditorStyle.ExceptionFill
        if (state = "recent")
            return EditorStyle.RecentFill
        if (IsNumber(state)) {
            strength := Min(Max(state + 0, 0), 1)
            alpha := Round(((EditorStyle.RecentFill >> 24) & 0xFF) * strength)
            return alpha > 0 ? ((alpha << 24) | (EditorStyle.RecentFill & 0xFFFFFF)) : ""
        }
        return ""
    }

    ; The shape of an element: its parts filled with brush. A condition is a diamond over its box; a loop has four
    ; parts (head, bar, foot and break field; the break field gets breakBrush).
    FillShape(canvas, brush, element, ox, oy, s, breakBrush := "") {
        parts := element.Parts
        if (element.Kind = "condition") {
            canvas.FillPolygon(brush, this.DiamondPoints(parts[1], ox, oy, s))
            return
        }
        head := parts[1]
        if (element.Kind = "loop") {
            ; one polygon for the whole body (no seams between the parts), the break field on top of it
            canvas.FillPolygon(brush, this.LoopPoints(parts, ox, oy, s))
            this.FillPart(canvas, (breakBrush = "") ? brush : breakBrush, parts[4], ox, oy, s)
            return
        }
        canvas.FillRoundRect(brush, (head.X - ox) * s, (head.Y - oy) * s, head.W * s, head.H * s,
            Renderer.RadiusOf(element.Kind) * s)
    }

    ; The outline of an element. A loop is one outline around the whole body: the seams between its parts (the bar,
    ; the foot, the break field) are not drawn, the break field is told by its fill (owner feedback, E0088).
    OutlineShape(canvas, pen, element, ox, oy, s) {
        parts := element.Parts
        if (element.Kind = "condition") {
            canvas.DrawPolygon(pen, this.DiamondPoints(parts[1], ox, oy, s))
            return
        }
        if (element.Kind = "loop") {
            canvas.DrawPolygon(pen, this.LoopPoints(parts, ox, oy, s))
            return
        }
        head := parts[1]
        canvas.DrawRoundRect(pen, (head.X - ox) * s, (head.Y - oy) * s, head.W * s, head.H * s,
            Renderer.RadiusOf(element.Kind) * s)
    }

    ; The outline of the body of a loop as one closed polygon (head, bar on the left, foot with the break field on the
    ; right). The bar is narrower than the head, so the outline steps in at the bar's right edge.
    LoopPoints(parts, ox, oy, s) {
        head := parts[1]
        bar := parts[2]
        foot := parts[3]
        left := (head.X - ox) * s
        right := (head.X + head.W - ox) * s
        top := (head.Y - oy) * s
        headBottom := (head.Y + head.H - oy) * s
        barRight := (bar.X + bar.W - ox) * s
        footTop := (foot.Y - oy) * s
        bottom := (foot.Y + foot.H - oy) * s
        return [[left, top], [right, top], [right, headBottom], [barRight, headBottom], [barRight, footTop]
            , [right, footTop], [right, bottom], [left, bottom]]
    }

    FillPart(canvas, brush, part, ox, oy, s) {
        canvas.FillRect(brush, (part.X - ox) * s, (part.Y - oy) * s, part.W * s, part.H * s)
    }

    DiamondPoints(head, ox, oy, s) {
        x := (head.X - ox) * s
        y := (head.Y - oy) * s
        w := head.W * s
        h := head.H * s
        return [[x + w / 2, y], [x + w, y + h / 2], [x + w / 2, y + h], [x, y + h / 2]]
    }

    static RadiusOf(kind) => EditorStyle.Radius.Has(kind) ? EditorStyle.Radius[kind] : 14

    BodyBrush(kind) {
        key := "fill." kind
        return this.tools.Has(key) ? this.tools[key] : this.tools["fill.action"]
    }

    ; The path of an icon of an element's package (the Icons folder of the package).
    IconPath(package, file) {
        return this.iconRoot "\" ((package = "") ? "Default" : package) "\Icons\" file
    }

    AssetPath(file) => this.assetRoot "\" file

    ; The icon fitted into a box of boxW x boxH, scaled once for that size: Array(image, width, height), or "" when the
    ; file cannot be read (the icon is then left out; the failure is kept, so the file is not read again).
    ScaledIcon(path, boxW, boxH) {
        src := this.Source(path)
        if (src = "" || src.width < 1 || src.height < 1)
            return ""
        k := Min(boxW / src.width, boxH / src.height)
        dw := Max(1, Round(src.width * k))
        dh := Max(1, Round(src.height * k))
        key := path "|" dw "x" dh
        if (!this.scaled.Has(key)) {
            if (this.scaled.Count >= Renderer.MAX_SCALED)
                this.DestroyMap(this.scaled)
            this.scaled[key] := GdipImage.Scaled(src, dw, dh)
        }
        return [this.scaled[key], dw, dh]
    }

    ; The image of a file, read once. "" for a file that cannot be read.
    Source(path) {
        if (!this.images.Has(path)) {
            try
                this.images[path] := GdipImage(path)
            catch
                this.images[path] := ""
        }
        return this.images[path]
    }

    ; A font of a size in device pixels (cached per size; the cache is small, a zoom gives a few sizes).
    FontFor(px) {
        key := Format("{:.2f}", px)
        if (!this.fonts.Has(key)) {
            if (this.fonts.Count >= Renderer.MAX_FONTS)
                this.DestroyMap(this.fonts)
            try
                this.fonts[key] := GdipFont(EditorStyle.TextFont, px)
            catch
                this.fonts[key] := GdipFont("Arial", px, 1)
        }
        return this.fonts[key]
    }

    NameFormat() {
        if (!this.format)
            this.format := GdipFormat(1, 1, true, true)
        return this.format
    }

    OverlayBrush(argb) {
        if (!this.overlays.Has(argb)) {
            if (this.overlays.Count >= Renderer.MAX_OVERLAYS)
                this.DestroyMap(this.overlays)
            this.overlays[argb] := GdipBrush(argb)
        }
        return this.overlays[argb]
    }

    ; The brushes, pens and text formats of one DPI (created once per DPI, destroyed when the DPI changes).
    EnsureTools(dpi) {
        if (IsObject(this.tools) && dpi = this.toolsDpi)
            return
        this.DestroyTools()
        k := dpi / 96
        t := Map()
        try {
            for kind, argb in EditorStyle.Fill
                t["fill." kind] := GdipBrush(argb)
            t["breakFill"] := GdipBrush(EditorStyle.BreakFill)
            t["breakText"] := GdipBrush(EditorStyle.BreakText)
            t["placeholder"] := GdipBrush(EditorStyle.Placeholder)
            t["placeholderText"] := GdipBrush(EditorStyle.PlaceholderText)
            t["text"] := GdipBrush(EditorStyle.Text)
            t["labelText"] := GdipBrush(EditorStyle.LabelText)
            t["gridDot"] := GdipBrush(EditorStyle.GridDot)
            t["warning"] := GdipBrush(EditorStyle.WarningBadge)
            t["badgeText"] := GdipBrush(EditorStyle.BadgeText)
            t["error"] := GdipBrush(EditorStyle.ErrorBadge)
            t["migration"] := GdipBrush(EditorStyle.MigrationBadge)
            t["border"] := GdipPen(EditorStyle.Border, EditorStyle.BorderWidth * k)
            t["placeholderLine"] := GdipPen(EditorStyle.PlaceholderBorder, EditorStyle.BorderWidth * k)
            t["line"] := GdipPen(EditorStyle.ConnectionColor, EditorStyle.ConnectionWidth * k)
            t["exceptionLine"] := GdipPen(EditorStyle.ExceptionColor, EditorStyle.ConnectionWidth * k)
            t["runLine"] := GdipPen(EditorStyle.RunningLineColor, EditorStyle.RunningLineWidth * k)
            t["formatLeft"] := GdipFormat(0, 1, false, false)
            t["formatRight"] := GdipFormat(2, 1, false, false)
            t["formatCenter"] := GdipFormat(1, 1, false, false)
        } catch as failure {
            for key, obj in t
                obj.Destroy()
            throw failure
        }
        this.tools := t
        this.toolsDpi := dpi
    }

    DestroyTools() {
        if (!IsObject(this.tools))
            return
        for key, obj in this.tools
            obj.Destroy()
        this.tools := ""
        this.toolsDpi := 0
    }

    ; Destroys every object of a cache Map (the objects have a Destroy method) and empties it.
    DestroyMap(cache) {
        for key, obj in cache {
            if (obj is Array)
                continue
            if (IsObject(obj))
                obj.Destroy()
        }
        cache.Clear()
    }
}
