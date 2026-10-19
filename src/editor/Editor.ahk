#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Role.ahk
#Include EditorModel.ahk
#Include render\Renderer.ahk
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
        this.renderer := ""           ; the Renderer, created when GDI+ is started (the first frame)
        this.canvas := ""             ; the offscreen bitmap of the headless driver (cmd.test.render)
        this.driver := ""
        this.started := false
        this.tornDown := false
        this.endReason := ""
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
        }
        this.model.Start()             ; subscriptions and the first resync; every reconnect asks again
    }

    OnShutdown(deadlineMs) {
        this._Teardown()
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
            case "log":
                this._Log("a1", "editor", this.name " " data)
        }
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
        return Map("ok", true)
    }

    ; The role part of the snapshot (PROTOCOL 4.9): the state of the model and the numbers of the renderer.
    DiagInfo() {
        st := this.model.State()
        info := Map("flowId", this.flowId, "rev", st["rev"], "engine", st["engine"], "epoch", st["epoch"], "seq", st["seq"]
            , "elements", st["elements"], "connections", st["connections"], "resyncs", st["resyncs"]
            , "lastResync", st["lastResync"], "headless", this.headless ? Json.True : Json.False
            , "windowVisible", Json.False)
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
