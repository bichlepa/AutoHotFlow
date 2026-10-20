#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include FlowStatus.ahk
#Include FlowTooltip.ahk
#Include FlowHitTest.ahk

; The headless driver of the editor (WI-0088, PROTOCOL 4.11), exists only with --headless: the test commands cmd.test.*
; of the editor role. There is no window: cmd.test.render draws the scene now into an offscreen bitmap of the given size,
; with the same renderer as the window. The commands answer at once (the render is synchronous).
;
;   cmd.test.state {}                   the state of the model, the view and the frame numbers (Driver.State)
;   cmd.test.render {w, h, dpi?, probes?}   draws now; probes are flow points [x, y]; answers ms and the colors (AARRGGBB)
;   cmd.test.close {}                   the planned end of the editor (after the answer)
;   cmd.test.view {zoomAt?, drag?, size?, dpi?}   the wheel, the drag, the size and the DPI of the window (WI-0090)
;   cmd.test.hover {x, y}               the tooltip text under a canvas pixel (WI-0090)
;   cmd.test.command {item, answer?}    a menu entry of the tray as if it was clicked (WI-0091, PROTOCOL 4.11): item show,
;                                       run, toggle or close; answer yes or no (default no) answers the questions of the entry
;
; Booleans on the wire are Json.True and Json.False (PROTOCOL 2): the state fields enabled and armed are written with Json.Bool.
class EditorDriver {
    static MAX_SIDE := 8000
    static TRAY_ITEMS := Map("show", 1, "run", 1, "toggle", 1, "close", 1)

    __New(role, model) {
        this.role := role
        this.model := model
        this.answer := "no"           ; the answer to the questions of the flow commands (ask seam, Confirm)
        this.asked := []              ; the kinds of the questions asked so far (EditorFlowOps)
        role.On("cmd.test.state", (msg) => Map("ok", true, "state", this.State()))
        role.On("cmd.test.render", (msg) => this._OnRender(msg))
        role.On("cmd.test.close", (msg) => this._OnClose())
        role.On("cmd.test.view", (msg) => this._OnView(msg))
        role.On("cmd.test.hover", (msg) => this._OnHover(msg))
        role.On("cmd.test.command", (msg) => this._OnCommand(msg))
    }

    ; The question of a flow command (the ask seam of EditorFlowOps): answered at once with the answer of the test.
    Confirm(kind, args, done) {
        this.asked.Push(kind)
        done(this.answer = "yes")
    }

    ; cmd.test.command {item, answer?}: runs the tray entry as the click does (EditorTray). The entry returns at once; the engine
    ; answer to Run or Enable or disable comes later, so a test reads its result in tray.lastResult (cmd.test.state).
    ; Close is the planned end: the answer goes out, then the role says bye.
    _OnCommand(msg) {
        p := msg.payload
        item := p.Get("item", "")
        answer := p.Get("answer", "no")
        if (IsObject(item) || !EditorDriver.TRAY_ITEMS.Has(item) || (answer != "yes" && answer != "no"))
            throw AhfError("cmd.test.command: item is show, run, toggle or close, answer yes or no", ErrCode.BAD_PAYLOAD)
        this.answer := answer
        switch item {
            case "show": this.role.tray.Show()
            case "run": this.role.tray.Run()
            case "toggle": this.role.tray.Toggle()
            case "close": this.role.tray.Close()
        }
        return Map("ok", true)
    }

    ; cmd.test.view {zoomAt?: {x, y, direction}, drag?: {dx, dy}, size?: {w, h}, dpi?}: the mouse and the window of the
    ; editor without a window. The steps run in this order: size and DPI, the wheel step (direction 1 in, -1 out, at the
    ; canvas pixel x, y), the drag (pixels; the content follows the pointer). Answers the view and the status bar text.
    _OnView(msg) {
        p := msg.payload
        size := p.Get("size", "")
        dpi := p.Get("dpi", "")
        view := this.model.view
        if (size is Map) {
            w := size.Get("w", 0), h := size.Get("h", 0)
            if (!IsInteger(w) || !IsInteger(h) || w < 1 || h < 1 || w > EditorDriver.MAX_SIDE || h > EditorDriver.MAX_SIDE)
                throw AhfError("cmd.test.view: size w and h are whole numbers from 1 to " EditorDriver.MAX_SIDE
                    , ErrCode.BAD_PAYLOAD)
            view := view.Resized(w, h, IsInteger(dpi) && dpi > 0 ? dpi : view.Dpi)
        } else if (IsInteger(dpi) && dpi > 0) {
            view := view.Resized(view.Width, view.Height, dpi)
        }
        zoomAt := p.Get("zoomAt", "")
        if (zoomAt is Map) {
            d := zoomAt.Get("direction", 0)
            if ((d != 1 && d != -1) || !IsNumber(zoomAt.Get("x", "")) || !IsNumber(zoomAt.Get("y", "")))
                throw AhfError("cmd.test.view: zoomAt is {x, y, direction} with direction 1 or -1", ErrCode.BAD_PAYLOAD)
            view := view.ZoomStep(d, zoomAt["x"], zoomAt["y"])
        }
        drag := p.Get("drag", "")
        if (drag is Map) {
            if (!IsNumber(drag.Get("dx", "")) || !IsNumber(drag.Get("dy", "")))
                throw AhfError("cmd.test.view: drag is {dx, dy} in pixels", ErrCode.BAD_PAYLOAD)
            view := view.Moved(drag["dx"], drag["dy"])
        }
        this.model.ChangeView(view)
        return Map("ok", true, "view", EditorDriver.ViewText(view), "status", this._Status())
    }

    ; cmd.test.hover {x, y}: what the tooltip shows at the canvas pixel x, y (the window waits about 0.5 s first). Answers
    ; the tooltip text ("" for none) and the kind ("element", "connection" or "") and ID of the item under the pixel.
    _OnHover(msg) {
        p := msg.payload
        x := p.Get("x", "")
        y := p.Get("y", "")
        if (!IsNumber(x) || !IsNumber(y))
            throw AhfError("cmd.test.hover: x and y are canvas pixels", ErrCode.BAD_PAYLOAD)
        sc := this.model.CurrentScene()
        if (sc = "")
            return Map("ok", false, "error", Map("code", ErrCode.BUSY, "message", "the flow is not loaded yet"))
        pt := sc.View.ToFlow(x, y)
        hit := FlowHitTest.At(sc, pt[1], pt[2])
        return Map("ok", true, "tooltip", FlowTooltip.Text(sc, hit, this.model.messages)
            , "kind", IsObject(hit) ? hit.Kind : "", "id", IsObject(hit) ? hit.Id : "")
    }

    ; The status bar text of the current view (FlowStatus).
    _Status() => FlowStatus.Text(this.model.view, this.model.ElementCount())

    static ViewText(view) => Map("zoom", view.Zoom, "offsetX", view.OffsetX, "offsetY", view.OffsetY, "dpi", view.Dpi
        , "width", view.Width, "height", view.Height)

    ; The state for the tests: the model (flow, states, resync), the view, and the numbers of the renderer.
    State() {
        m := this.model.State()
        st := Map("flowId", m["flowId"], "name", m["name"], "rev", m["rev"], "elements", m["elements"]
            , "connections", m["connections"], "states", EditorDriver._StatesText(m["run"]), "fading", m["fading"]
            , "warnings", m["warnings"].Clone(), "messages", m["messages"].Clone()
            , "engine", m["engine"], "epoch", m["epoch"], "seq", m["seq"], "resyncs", m["resyncs"]
            , "lastResync", m["lastResync"], "latency", m["latency"], "ended", m["ended"])
        triggers := Map()
        for id, t in m["triggers"]
            triggers[id] := Map("enabled", Json.Bool(t["enabled"]), "armed", Json.Bool(t["armed"]), "message", t["message"])
        st["triggers"] := triggers
        fs := m["flowState"]
        st["flowState"] := Map("enabled", Json.Bool(fs["enabled"]), "independentActive", fs["independentActive"]
            , "executing", Json.Bool(fs["executing"]), "instances", fs["instances"], "stateError", fs["stateError"])
        v := this.model.view
        st["view"] := Map("zoom", v.Zoom, "offsetX", v.OffsetX, "offsetY", v.OffsetY, "dpi", v.Dpi
            , "width", v.Width, "height", v.Height)
        r := IsObject(this.role.renderer) ? this.role.renderer.Snapshot() : Map("frames", 0, "meanFrameMs", 0
            , "lastFrameMs", 0, "slowestFrameMs", 0, "rebuilds", 0, "lastRebuildMs", 0)
        st["status"] := this._Status()
        st["tray"] := this.role.tray.State()
        st["asked"] := this.asked.Clone()
        st["frames"] := r["frames"]
        st["meanFrameMs"] := r["meanFrameMs"]
        st["lastFrameMs"] := r["lastFrameMs"]
        st["slowestFrameMs"] := r["slowestFrameMs"]
        st["rebuilds"] := r["rebuilds"]
        return st
    }

    ; The run states as the frame shows them: "running", "exception", or "recent" for a fade. The strength of a fade is not
    ; sent (it is a float; the snapshot keeps whole numbers); "fading" counts the IDs that fade.
    static _StatesText(run) {
        out := Map()
        for id, state in run
            out[id] := IsNumber(state) ? "recent" : state
        return out
    }

    ; cmd.test.render {w, h, dpi?, probes?}: the scene drawn into an offscreen bitmap of w x h pixels. The view takes the size.
    _OnRender(msg) {
        p := msg.payload
        w := p.Get("w", 0)
        h := p.Get("h", 0)
        dpi := p.Get("dpi", 96)
        if (!IsInteger(w) || !IsInteger(h) || w < 1 || h < 1 || w > EditorDriver.MAX_SIDE || h > EditorDriver.MAX_SIDE
            || !IsInteger(dpi) || dpi < 1)
            throw AhfError("cmd.test.render: w and h are whole numbers from 1 to " EditorDriver.MAX_SIDE, ErrCode.BAD_PAYLOAD)
        probes := p.Get("probes", [])
        if (!(probes is Array))
            throw AhfError("cmd.test.render: probes is a list of [x, y]", ErrCode.BAD_PAYLOAD)
        renderer := this.role._Renderer()
        this.model.SetCanvas(w, h, dpi)
        sc := this.model.CurrentScene()
        if (sc = "")
            return Map("ok", false, "error", Map("code", ErrCode.BUSY, "message", "the flow is not loaded yet"))
        canvas := this.role.canvas
        if (!IsObject(canvas) || canvas.width != w || canvas.height != h) {
            if (IsObject(canvas))
                canvas.Destroy()
            canvas := GdipCanvas(w, h)
            this.role.canvas := canvas
        }
        renderer.Draw(sc, canvas)
        this.model.NoteFrame()
        colors := []
        for probe in probes {
            if (!(probe is Array) || probe.Length != 2 || !IsNumber(probe[1]) || !IsNumber(probe[2]))
                throw AhfError("cmd.test.render: a probe is [x, y] in flow points", ErrCode.BAD_PAYLOAD)
            pt := sc.View.ToCanvas(probe[1], probe[2])
            x := Round(pt[1])
            y := Round(pt[2])
            if (x < 0 || y < 0 || x >= w || y >= h)
                colors.Push("")
            else
                colors.Push(Format("{:08X}", canvas.Pixel(x, y)))
        }
        return Map("ok", true, "ms", renderer.LastFrameMs, "colors", colors, "frames", renderer.FramesDrawn)
    }

    ; cmd.test.close: the answer goes first (the role ends after it, with the planned end).
    _OnClose() {
        this.model.Finish("test")
        return Map("ok", true)
    }
}
