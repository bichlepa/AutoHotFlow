#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk

; The headless driver of the editor (WI-0088, PROTOCOL 4.11), exists only with --headless: the test commands cmd.test.*
; of the editor role. There is no window: cmd.test.render draws the scene now into an offscreen bitmap of the given size,
; with the same renderer as the window. The commands answer at once (the render is synchronous).
;
;   cmd.test.state {}                   the state of the model, the view and the frame numbers (Driver.State)
;   cmd.test.render {w, h, dpi?, probes?}   draws now; probes are flow points [x, y]; answers ms and the colors (AARRGGBB)
;   cmd.test.close {}                   the planned end of the editor (after the answer)
;
; Booleans on the wire are Json.True and Json.False (PROTOCOL 2): the state fields enabled and armed are written with Json.Bool.
class EditorDriver {
    static MAX_SIDE := 8000

    __New(role, model) {
        this.role := role
        this.model := model
        role.On("cmd.test.state", (msg) => Map("ok", true, "state", this.State()))
        role.On("cmd.test.render", (msg) => this._OnRender(msg))
        role.On("cmd.test.close", (msg) => this._OnClose())
    }

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
