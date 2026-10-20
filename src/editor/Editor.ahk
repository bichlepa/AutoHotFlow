#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk
#Include EditorModel.ahk
#Include render\Renderer.ahk
#Include EditorWindow.ahk
#Include EditorDriver.ahk

; Role "editor" (WI-0088, PROTOCOL 4.11, ARCHITECTURE 2.1 and 3): shows one flow and follows its run states. One process per
; flow (D0002). The role holds no truth: EditorModel asks the engine for the state and the definition and follows its
; events; this class connects the model with the renderer, the window (EditorWindow, not with --headless) and the headless
; driver (EditorDriver: the test commands cmd.test.*, only with --headless).
;
;   AutoHotkey64.exe src\entry\editor.ahk --role=editor --flow=<flowId> --session=<id> --hub=<pipe> --data=<dir> [--headless]
;
; A missing --flow is a bad argument (exit 2, AhfBoot). The planned end (the window closed, a deleted flow, a flow that does
; not exist at the start, cmd.test.close) is a clean sys.bye and exit 0: the supervisor does not report it and does not
; restart the editor.
class Editor extends Role {
    __New(args) {
        super.__New(args)
        if (this.flowId = "")
            throw AhfError("the editor needs --flow=<flowId>", ErrCode.BAD_ARGS)
        this.headless := args.Has("headless")
        this.model := ""
        this.window := ""             ; the EditorWindow (not with --headless)
        this.renderer := ""           ; the Renderer, created when GDI+ is started (the first frame)
        this.canvas := ""             ; the offscreen bitmap of the headless driver (cmd.test.render)
        this.driver := ""
        this.started := false
        this.tornDown := false
        this.endReason := ""
        this.frameScheduled := false  ; headless only: a frame timer is set (the window has its own, EditorWindow)
        this.lastFrameMs := 0
        this.frameFn := () => this._HeadlessFrame()
    }

    RegisterHandlers() {
        this.model := EditorModel(this.peer, this.flowId)
        this.model.later := (ms, fn) => SetTimer(fn, -ms)
        this.model.AddListener((kind, data) => this._OnModel(kind, data))
        this.On("evt.", (msg) => this.model.OnEvent(msg.type, msg.payload))
        this.On("cmd.editor.show", (msg) => this._OnShow(msg))
        this.On("cmd.app.prepareExit", (msg) => Map("ok", true, "cancel", Json.False))
        this.FollowSettings()          ; the language (WI-0077): the title follows it
        if (this.headless)
            this.driver := EditorDriver(this, this.model)
    }

    OnReady() {
        this.SetLogTarget("storage")
        if (!this.started) {
            this.started := true
            this._Log("a1", "editor", this.name " ready" (this.headless ? " (headless)" : ""))
            if (!this.headless) {
                this.window := EditorWindow(this)
                this.window.Show()
            }
        }
        this.model.Start()             ; subscriptions and the first resync; every reconnect asks again
    }

    OnShutdown(deadlineMs) {
        this._Teardown()
    }

    ; The settings changed (WI-0077): the language is applied already; the title gets the new text.
    OnSettings(settings) {
        if (IsObject(this.window))
            this.window.Refresh()
    }

    ; The close box of the window: the planned end of the editor.
    _OnWindowClose() {
        this._EndPlanned("closed")
    }

    ; The planned end of the editor: the window and the GDI+ objects go, then the role says bye (Role.ByeFn).
    _EndPlanned(reason) {
        if (this.endReason != "")
            return
        this.endReason := reason
        this._Log("a1", "editor", this.name " ends: " reason)
        this._Teardown()
        SetTimer(Role.ByeFn, -1)
    }

    ; Frees the GDI+ objects of the role (renderer, offscreen bitmap) and stops GDI+. Called once, at the end.
    _Teardown() {
        if (this.tornDown)
            return
        this.tornDown := true
        SetTimer(this.frameFn, 0)
        this.frameScheduled := false
        if (IsObject(this.window)) {
            this.window.Close()
            this.window := ""
        }
        if (IsObject(this.canvas)) {
            this.canvas.Destroy()
            this.canvas := ""
        }
        if (IsObject(this.renderer)) {
            this.renderer.Destroy()
            this.renderer := ""
        }
        Gdip.Shutdown()
    }

    ; The renderer exists once GDI+ runs: created at the first frame, not at the start (a role without a frame needs no GDI+).
    _Renderer() {
        if (!IsObject(this.renderer)) {
            Gdip.Startup()
            this.renderer := Renderer()
        }
        return this.renderer
    }

    _OnModel(kind, data) {
        switch kind {
            case "ended":
                this._OnEnded(data)
            case "state":
                this._Repaint()
            case "flow":
                if (IsObject(this.window))
                    this.window.Refresh()
                this._Repaint()
            case "log":
                this._Log("a1", "editor", this.name " " data)
        }
    }

    ; A frame is wanted: the window asks for one, the headless editor draws one itself (the same renderer, the same rule of
    ; at most one frame per FRAME_MS; without a canvas, from cmd.test.render on, there is nothing to draw).
    _Repaint() {
        if (IsObject(this.window))
            this.window.Request()
        else if (this.headless)
            this._RequestHeadless()
    }

    _RequestHeadless() {
        if (this.frameScheduled || this.tornDown || !IsObject(this.canvas))
            return
        this.frameScheduled := true
        wait := Max(1, EditorWindow.FRAME_MS - (Time.NowMs() - this.lastFrameMs))   ; SetTimer(fn, -0) would switch it off
        SetTimer(this.frameFn, -wait)
    }

    ; The timer of a headless frame: draws the scene into the offscreen bitmap, as the window does (WI-0089, REQ-PRF-060).
    _HeadlessFrame() {
        this.frameScheduled := false
        if (this.tornDown || !IsObject(this.canvas))
            return
        sc := this.model.CurrentScene()
        if (sc = "")
            return
        this.lastFrameMs := Time.NowMs()
        try {
            this._Renderer().Draw(sc, this.canvas)
        } catch as e {
            this._Log("a0", "editor", "frame failed: " Type(e) ": " e.Message)
            return
        }
        this.model.NoteFrame()
    }

    ; The end of the model. A flow that does not exist at the start gets a notice (the manager shows it); a deleted flow does
    ; not (the manager shows the deletion itself).
    _OnEnded(reason) {
        if (reason = "not_found")
            this._Notice("Editor_flow_missing", [this.flowId])
        this._EndPlanned(reason)
    }

    ; An evt.ui.notice of kind app to the manager (topic notice, WI-0075).
    _Notice(key, args) {
        try {
            this.peer.Send("topic:notice", "evt.ui.notice", Map("kind", "app", "level", "error", "key", key
                , "args", args, "flowId", this.flowId, "held", 0))
        } catch as e {
            this._Log("a0", "editor", "notice " key " not sent: " Type(e) ": " e.Message)
        }
    }

    ; cmd.editor.show (PROTOCOL 4.11): the window comes to the front. Without a window only the call is recorded.
    _OnShow(msg) {
        if (IsObject(this.window))
            this.window.Raise()
        return Map("ok", true)
    }

    ; The role part of the snapshot (PROTOCOL 4.9): the state of the model and the numbers of the renderer.
    DiagInfo() {
        st := this.model.State()
        info := Map("flowId", this.flowId, "rev", st["rev"], "engine", st["engine"], "epoch", st["epoch"], "seq", st["seq"]
            , "elements", st["elements"], "connections", st["connections"], "resyncs", st["resyncs"]
            , "lastResync", st["lastResync"], "headless", this.headless ? Json.True : Json.False
            , "windowVisible", (IsObject(this.window) && this.window.Visible) ? Json.True : Json.False)
        r := IsObject(this.renderer) ? this.renderer.Snapshot() : Map("frames", 0, "meanFrameMs", 0, "slowestFrameMs", 0
            , "rebuilds", 0, "lastFrameMs", 0)
        info["frames"] := r["frames"]
        info["meanFrameMs"] := r["meanFrameMs"]
        info["lastFrameMs"] := r["lastFrameMs"]
        info["slowestFrameMs"] := r["slowestFrameMs"]
        info["rebuilds"] := r["rebuilds"]
        return info
    }
}
