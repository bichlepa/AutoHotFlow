#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk
#Include EditorModel.ahk
#Include render\Renderer.ahk
#Include EditorFlowOps.ahk
#Include EditorAdd.ahk
#Include EditorConnect.ahk
#Include EditorTransfer.ahk
#Include EditorTriggers.ahk
#Include EditorMenus.ahk
#Include EditorSettings.ahk
#Include ElementSettingsWindow.ahk
#Include EditorTray.ahk
#Include EditorPointer.ahk
#Include EditorKeys.ahk
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
        this.pointer := ""            ; EditorPointer: the mouse of the editor (selection, moves, view; WI-0098)
        this.window := ""             ; the EditorWindow (not with --headless)
        this.renderer := ""           ; the Renderer, created when GDI+ is started (the first frame)
        this.canvas := ""             ; the offscreen bitmap of the headless driver (cmd.test.render)
        this.driver := ""
        this.flowOps := ""            ; EditorFlowOps: Run and Enable or disable (the tray menu, the questions of the window)
        this.add := ""                ; EditorAdd: a new element, placed by the pointer and given its class (WI-0099)
        this.connect := ""            ; EditorConnect: connections drawn, moved and typed with the pointer (WI-0100)
        this.transfer := ""           ; EditorTransfer: delete, cut, copy and paste of the elements (WI-0101)
        this.triggers := ""           ; EditorTriggers: the switch and the star of a trigger (WI-0102)
        this.menus := ""              ; EditorMenus: the menu bar, the context menus and the menu commands (WI-0102)
        this.settings := ""           ; EditorSettings: the settings of an element or of a new one (WI-0106)
        this.settingsWindow := ""     ; ElementSettingsWindow (not with --headless)
        this.tray := ""               ; EditorTray: the icon and the menu of this editor (REQ-EDT-230)
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
        this.model.session := this.session
        this.model.AddListener((kind, data) => this._OnModel(kind, data))
        this.pointer := EditorPointer(this.model)
        this.add := EditorAdd(this.model)
        this.connect := EditorConnect(this.model, this.add)     ; the connections (WI-0100): the buttons, the drop, the questions
        this.transfer := EditorTransfer(this.model)              ; delete, cut, copy and paste (WI-0101)
        this.pointer.connect := this.connect
        this.pointer.transfer := this.transfer
        this.triggers := EditorTriggers(this.peer, this.flowId, this.model)
        this.pointer.triggers := this.triggers
        this.menus := EditorMenus(this)
        this.settings := EditorSettings(this.model)          ; the settings of an element (WI-0106)
        this.settings.adder := this.add
        this.add.settings := this.settings                    ; a new element gets its settings before it is added
        this.pointer.onSettings := (id) => this.settings.Open(id)     ; the edit button and a double click (WI-0106)
        this.pointer.commands := this.menus                 ; Ctrl+Z, Ctrl+Y and Ctrl+S (EditorKeys)
        this.pointer.onContext := (cx, cy, fx, fy) => this.menus.Open(cx, cy, fx, fy)     ; the right click (WI-0102)
        this.pointer.onPlace := (kind, x, y) => this.add.Placed(kind, x, y)
        this.On("evt.", (msg) => this.model.OnEvent(msg.type, msg.payload))
        this.On("cmd.editor.show", (msg) => this._OnShow(msg))
        this.On("cmd.app.prepareExit", (msg) => Map("ok", true, "cancel", Json.False))
        this.FollowSettings()          ; the language (WI-0077): the title follows it
        this.flowOps := EditorFlowOps(this.peer, this.flowId, this.model)
        this.tray := EditorTray(this, this.headless)
        if (this.headless) {
            this.driver := EditorDriver(this, this.model)
            this.flowOps.ask := this.driver      ; the questions of the flow commands are answered by the test
            this.add.chooser := this.driver      ; the class list of a new element is answered by the test (cmd.test.class)
            this.connect.picker := this.driver   ; the questions of a connection are answered by the test (cmd.test.pick)
            this.transfer.ask := this.driver     ; the question of Del is answered by the test (cmd.test.key answer)
        }
    }

    OnReady() {
        this.SetLogTarget("storage")
        if (!this.started) {
            this.started := true
            this._Log("a1", "editor", this.name " ready" (this.headless ? " (headless)" : ""))
            if (!this.headless) {
                this.window := EditorWindow(this)
                this.flowOps.ask := this.window
                this.add.chooser := this.window
                this.connect.picker := this.window
                this.transfer.ask := this.window
                this.window.SetMenuBar(this.menus.Bar())
                this.window.Show()
                this.settingsWindow := ElementSettingsWindow(this.window.hwnd)
                this.settings.window := this.settingsWindow
            }
            this.tray.Start()              ; the icon of this editor (hidden with --headless), its menu, the window icon
        }
        this.model.Start()             ; subscriptions and the first resync; every reconnect asks again
    }

    OnShutdown(deadlineMs) {
        this._Teardown()
    }

    ; The settings changed (WI-0077): the language is applied already; the title gets the new text.
    OnSettings(settings) {
        if (IsObject(this.window)) {
            this.window.Refresh()
            this.window.SetMenuBar(this.menus.Bar())      ; the menu texts follow the language (WI-0102)
        }
        if (IsObject(this.settingsWindow))
            this.settingsWindow.Refresh()                  ; an open settings window is drawn again (WI-0106)
        if (IsObject(this.add))
            this.add.userLevel := settings.Get("userLevel", "Beginner")     ; the class list of a new element (REQ-USE-010)
        this._Tray()
    }

    ; The planned end of the editor by the user: the close box of the window and the tray menu (Close, as the close box).
    CloseEditor() {
        this._EndPlanned("closed")
    }

    ; The planned end of the editor: the view is written (E0086, at most EditorModel.FLUSH_MS), the window and the GDI+
    ; objects go, then the role says bye (Role.ByeFn). A deleted flow or one that does not exist has no view to write.
    _EndPlanned(reason) {
        if (this.endReason != "")
            return
        this.endReason := reason
        this._Log("a1", "editor", this.name " ends: " reason)
        bye := () => this._Bye()
        if (reason = "deleted" || reason = "not_found")
            bye()
        else
            this.model.FlushView(bye)      ; the window stays until the view is answered (or FLUSH_MS have passed)
    }

    _Bye() {
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
        if (IsObject(this.tray))
            this.tray.Stop()
        if (IsObject(this.settings))
            this.settings.Discard()                       ; an open settings window goes first (WI-0106)
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
                this._Status()
                this._Tray()
                this._Repaint()
            case "view":
                this._Status()
                this._Repaint()
            case "flow":
                if (IsObject(this.window))
                    this.window.Refresh()
                this._Status()
                this._Tray()
                this._Repaint()
            case "log":
                this._Log("a1", "editor", this.name " " data)
        }
    }

    ; The icon, the tooltip and the menu follow the flow state and its name (REQ-EDT-230).
    _Tray() {
        if (IsObject(this.tray))
            this.tray.Refresh()
        if (IsObject(this.menus))
            this.menus.Refresh()                 ; the menu bar follows the same changes (WI-0102)
    }

    ; cmd.editor.show and the tray entry Show: the window comes to the front (without a window nothing happens).
    ShowWindow() {
        if (IsObject(this.window))
            this.window.Raise()
    }

    ; The status bar follows the view, the flow and the states (WI-0090); headless there is no bar.
    _Status() {
        if (IsObject(this.window))
            this.window.UpdateStatus()
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
        this.ShowWindow()
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
        info["tray"] := IsObject(this.tray) ? this.tray.State() : Map()
        return info
    }
}
