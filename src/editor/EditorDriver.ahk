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
;   cmd.test.edit {ops}                 the operations as one undo step (WI-0096, EditorDraft.Commit)
;   cmd.test.undo {}, cmd.test.redo {}  one step of the undo or the redo stack
;   cmd.test.select {mode, ids?}        the selection: one, toggle, all or none (WI-0096)
;   cmd.test.mouse {button, action, x, y, ctrl?}   the mouse as the window gets it (WI-0098): button left, right (none for a
;                                       move without a button); action down, move, up or double (two clicks). The same
;                                       pointer methods as the window (EditorPointer)
;   cmd.test.key {key, ctrl?, shift?}   a key of the editor window as WM_KEYDOWN gives it (WI-0098, EditorKeys): key "Esc" or
;                                       one letter; answers handled (the table has it)
;   cmd.test.class {id}                 the answer of the open class list of a new element (WI-0099): the qualified ID the list
;                                       offers, or "" for Cancel. The list is in cmd.test.state (choice)
;   cmd.test.pick {id}                  the answer of the open question of a connection (WI-0100): a kind, a type, or "" for
;                                       Cancel. The question is in cmd.test.state (pick)
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
        this.choice := ""             ; the open class list of a new element: Map(kind, groups, done), or "" (WI-0099)
        this.question := ""           ; the open question of a connection: Map(title, text, buttons, done), or "" (WI-0100)
        role.On("cmd.test.state", (msg) => Map("ok", true, "state", this.State()))
        role.On("cmd.test.render", (msg) => this._OnRender(msg))
        role.On("cmd.test.close", (msg) => this._OnClose())
        role.On("cmd.test.view", (msg) => this._OnView(msg))
        role.On("cmd.test.hover", (msg) => this._OnHover(msg))
        role.On("cmd.test.command", (msg) => this._OnCommand(msg))
        role.On("cmd.test.mouse", (msg) => this._OnMouse(msg))
        role.On("cmd.test.key", (msg) => this._OnKey(msg))
        role.On("cmd.test.edit", (msg) => this._OnEdit(msg))
        role.On("cmd.test.undo", (msg) => this._OnStep(msg, "undo"))
        role.On("cmd.test.redo", (msg) => this._OnStep(msg, "redo"))
        role.On("cmd.test.select", (msg) => this._OnSelect(msg))
        role.On("cmd.test.class", (msg) => this._OnClass(msg))
        role.On("cmd.test.pick", (msg) => this._OnPick(msg))
    }

    ; The question of a connection (the picker seam of EditorConnect): it stays open until cmd.test.pick answers it.
    Pick(titleKey, textKey, buttons, done) {
        this.question := Map("title", titleKey, "text", textKey, "buttons", buttons, "done", done)
    }

    ; cmd.test.pick {id}: the answer of the open question. id "" cancels; any other id must be one of its buttons.
    _OnPick(msg) {
        if (!IsObject(this.question))
            return Map("ok", false, "error", Map("code", ErrCode.BUSY, "message", "no question of a connection is open"))
        id := msg.payload.Get("id", "")
        if (IsObject(id) || (id != "" && !EditorDriver._HasButton(this.question["buttons"], id)))
            return Map("ok", false, "error", Map("code", ErrCode.BAD_PAYLOAD, "message", "id is one of the buttons, or empty"))
        done := this.question["done"]
        this.question := ""
        done(id)
        return Map("ok", true)
    }

    static _HasButton(buttons, id) {
        for button in buttons {
            if (button[1] = id)
                return true
        }
        return false
    }

    ; The open question for the state: its title and the IDs of its buttons ("" when none is open).
    _PickText() {
        if (!IsObject(this.question))
            return ""
        ids := []
        for button in this.question["buttons"]
            ids.Push(button[1])
        return Map("title", this.question["title"], "ids", ids)
    }

    ; The class list of a new element (the chooser seam of EditorAdd): it stays open until cmd.test.class answers it.
    Choose(kind, groups, done) {
        this.choice := Map("kind", kind, "groups", groups, "done", done)
    }

    ; cmd.test.class {id}: the answer of the open list. id "" cancels; any other id must be one the list offers.
    _OnClass(msg) {
        if (!IsObject(this.choice))
            return Map("ok", false, "error", Map("code", ErrCode.BUSY, "message", "no class list is open"))
        id := msg.payload.Get("id", "")
        if (IsObject(id) || (id != "" && !EditorDriver._Offers(this.choice["groups"], id)))
            return Map("ok", false, "error", Map("code", ErrCode.BAD_PAYLOAD, "message", "id is one the list offers, or empty"))
        done := this.choice["done"]
        this.choice := ""
        done(id)
        return Map("ok", true)
    }

    static _Offers(groups, id) {
        for group in groups {
            for item in group[2] {
                if (item[1] = id)
                    return true
            }
        }
        return false
    }

    ; The open class list for the state: its kind and its items in the order of the list ("" when none is open).
    _ChoiceText() {
        if (!IsObject(this.choice))
            return ""
        items := []
        for group in this.choice["groups"] {
            for item in group[2]
                items.Push(Map("category", group[1], "id", item[1], "label", item[2]))
        }
        return Map("kind", this.choice["kind"], "items", items)
    }

    ; cmd.test.mouse {button, action, x, y, ctrl?}: the same calls as the window makes for its messages (EditorWindow._OnDown,
    ; _OnMove, _OnUp). The answer is the mode of the pointer and the selection.
    _OnMouse(msg) {
        p := msg.payload
        button := p.Get("button", "")
        action := p.Get("action", "")
        x := p.Get("x", "")
        y := p.Get("y", "")
        if (!IsNumber(x) || !IsNumber(y))
            throw AhfError("cmd.test.mouse: x and y are canvas pixels", ErrCode.BAD_PAYLOAD)
        if (IsObject(button) || IsObject(action))
            throw AhfError("cmd.test.mouse: button and action are texts", ErrCode.BAD_PAYLOAD)
        moveWithoutButton := (action = "move" && button = "none")
        if (!(button = "left" || button = "right" || moveWithoutButton)
                || !(action = "down" || action = "move" || action = "up" || action = "double"))
            throw AhfError("cmd.test.mouse: button left or right (none for a move), action down, move, up or double",
                ErrCode.BAD_PAYLOAD)
        ctrl := EditorDriver._Flag(p.Get("ctrl", 0))
        pointer := this.role.pointer
        switch action {
            case "down":
                pointer.Down(button, x, y, ctrl)
            case "up":
                pointer.Up(button, x, y)
            case "move":
                pointer.Move(x, y, moveWithoutButton ? "" : button)
            case "double":
                pointer.Down(button, x, y, ctrl)
                pointer.Up(button, x, y)
                pointer.Down(button, x, y, ctrl)
                pointer.Up(button, x, y)
        }
        return Map("ok", true, "pointer", pointer.CurrentMode, "selection", this.model.SelectionIds(), "status", this._Status())
    }

    ; cmd.test.key {key, ctrl?, shift?}: the key as the window gets it (WM_KEYDOWN, EditorKeys). handled: the table has it.
    _OnKey(msg) {
        p := msg.payload
        key := p.Get("key", "")
        isLetter := (Type(key) = "String" && StrLen(key) = 1 && RegExMatch(key, "^[A-Za-z]$"))
        if (!(Type(key) = "String" && key = "Esc") && !isLetter)
            throw AhfError("cmd.test.key: key is Esc or one letter", ErrCode.BAD_PAYLOAD)
        name := EditorKeys.Name(key, EditorDriver._Flag(p.Get("ctrl", 0)), EditorDriver._Flag(p.Get("shift", 0)))
        handled := EditorKeys.Handle(this.role.pointer, name)
        return Map("ok", true, "handled", Json.Bool(handled), "selection", this.model.SelectionIds()
            , "status", this._Status())
    }

    ; True for a JSON true (1, or the Json.True object) in a payload; false, 0 and missing values are false.
    static _Flag(v) => IsObject(v) ? (v == Json.True) : (IsNumber(v) && v != 0)

    ; cmd.test.edit {ops}: the operations as one undo step (EditorDraft.Commit). Answers at once; the engine's answer comes
    ; later (cmd.test.state shows pending while it is on its way).
    _OnEdit(msg) {
        ops := msg.payload.Get("ops", "")
        if (!(ops is Array))
            throw AhfError("cmd.test.edit: ops is a list of operations", ErrCode.BAD_PAYLOAD)
        res := this.model.draft.Commit(ops, true)
        if (!res["ok"])
            return Map("ok", false, "error", Map("code", res["code"], "message", res["message"]))
        return Map("ok", true)
    }

    ; cmd.test.undo and cmd.test.redo: one step. done is false when there is no step; a refused step is not ok.
    _OnStep(msg, what) {
        res := (what = "undo") ? this.model.draft.Undo() : this.model.draft.Redo()
        if (!res["ok"])
            return Map("ok", false, "done", false, "error", Map("code", ErrCode.BAD_PAYLOAD
                , "message", res.Get("message", "")), "status", this.model.StatusText())
        return Map("ok", true, "done", res["done"], "status", this.model.StatusText())
    }

    ; cmd.test.select {mode, ids?}: one, toggle, all or none (EditorDraft.SetSelection).
    _OnSelect(msg) {
        p := msg.payload
        mode := p.Get("mode", "")
        ids := p.Get("ids", [])
        if (!EditorDraft.SELECT_MODES.Has(mode) || !(ids is Array))
            throw AhfError("cmd.test.select: mode is one, toggle, all or none, ids a list", ErrCode.BAD_PAYLOAD)
        this.model.draft.SetSelection(ids, mode)
        this.model.SelectionChanged()
        return Map("ok", true, "selection", this.model.State()["selection"])
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
    _Status() => this.model.StatusText()

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
        st["selection"] := m["selection"]
        st["pointer"] := this.role.pointer.CurrentMode          ; "", press, move, tail, rect or view (WI-0098)
        st["undo"] := m["undo"]
        st["redo"] := m["redo"]
        st["pending"] := m["pending"]
        st["choice"] := this._ChoiceText()
        st["pick"] := this._PickText()                        ; the open question of a connection (WI-0100)
        sc := this.model.CurrentScene()
        g := IsObject(sc) ? sc.Ghost : ""                     ; the box of a new element being placed (WI-0099)
        st["ghost"] := (g is FlowRect) ? Map("x", g.X, "y", g.Y, "w", g.W, "h", g.H) : ""
        st["buttons"] := EditorDriver._ButtonsText(sc)        ; the buttons of the selection, at their flow centres (WI-0100)
        st["tray"] := this.role.tray.State()
        st["asked"] := this.asked.Clone()
        st["frames"] := r["frames"]
        st["meanFrameMs"] := r["meanFrameMs"]
        st["lastFrameMs"] := r["lastFrameMs"]
        st["slowestFrameMs"] := r["slowestFrameMs"]
        st["rebuilds"] := r["rebuilds"]
        return st
    }

    ; The buttons of the scene as Array of Maps("name", "id", "x", "y") in flow units, the centre of each (WI-0100).
    static _ButtonsText(sc) {
        out := []
        if (!IsObject(sc))
            return out
        for button in sc.Buttons {
            r := button["rect"]
            out.Push(Map("name", button["name"], "id", button["id"], "x", r.X + r.W / 2, "y", r.Y + r.H / 2))
        }
        return out
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
