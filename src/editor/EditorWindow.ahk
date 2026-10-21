#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Time.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ..\ui_common\UiDialogs.ahk
#Include render\Renderer.ahk
#Include FlowHitTest.ahk
#Include FlowStatus.ahk
#Include FlowTooltip.ahk
#Include EditorFlowOps.ahk
#Include EditorTray.ahk
#Include EditorKeys.ahk

; The window of the editor (WI-0088, REQ-EDT-010, REQ-EDT-020, ARCHITECTURE 2.1): a UiWindow whose client area shows the
; back buffer of the renderer. The window copies the back buffer in WM_PAINT and answers WM_ERASEBKGND itself, so nothing
; flickers. A frame is drawn into the back buffer only when the scene changed, at most one per FRAME_MS (33 ms, about 30
; frames per second); the copy follows with InvalidateRect. Drawing happens in a timer, never in the message of a request
; (rule 3 of AGENTS.md: no blocking call on the message path).
;
; Title (v1: "AutoHotFlow " lang("Editor") " - " flowName): set again when the language or the name of the flow changes.
; First size: 90 % of the work area of the primary monitor (v1), in the sizes of UiWindow (96 dpi). A remembered place of
; the process wins (UiWindow). The close box calls the role's end (a planned end: the role says bye, exit 0).
;
; The mouse (WI-0090, WI-0098, REQ-EDT-030, REQ-EDT-060, E0094): the wheel zooms at the pointer (factor 1.1). The buttons go to
; the pointer (EditorPointer: selection, rectangle, move, loop height on the left button; the view on the right one). The
; pointer holds the mouse while it works (SetCapture, released when it stops holding); a drag follows WM_MOUSEMOVE and never
; loops with Sleep (v1 did). A tooltip (FlowTooltip) appears when the mouse has rested HOVER_MS on the flow, and hides on the
; next move or when the mouse leaves the window. The keys come as WM_KEYDOWN of this window (EditorKeys), never as hotkeys.
;
; The status bar (FlowStatus: offset, zoom, number of elements, v1 texts) is a native StatusBar below the canvas; the canvas
; is the client area above it.
class EditorWindow {
    static FRAME_MS := 33
    static WM_PAINT := 0x000F
    static WM_ERASEBKGND := 0x0014
    static WM_SIZE := 0x0005
    static WM_MOUSEMOVE := 0x0200
    static WM_LBUTTONDOWN := 0x0201
    static WM_LBUTTONUP := 0x0202
    static WM_LBUTTONDBLCLK := 0x0203      ; the second press of a double click: the pointer gets it as a press (WI-0100)
    static WM_RBUTTONDOWN := 0x0204
    static WM_RBUTTONUP := 0x0205
    static WM_MOUSEWHEEL := 0x020A
    static WM_MOUSELEAVE := 0x02A3
    static WM_KEYDOWN := 0x0100
    static WM_ACTIVATE := 0x0006           ; the menu bar is brought up to date when the window is activated (paste, WI-0104)
    static SIZE_SHARE := 0.9
    static HOVER_MS := 500
    static WHEEL_NOTCH := 120

    __New(role) {
        this.role := role
        this.canvas := ""             ; the back buffer, the size of the client area above the status bar
        this.scheduled := false       ; a frame timer is set
        this.lastFrameMs := 0
        this.lastVersion := -1        ; the scene version of the last frame that was drawn
        this.frames := 0
        this.closed := false
        this.tracking := false        ; TrackMouseEvent is set for the next WM_MOUSELEAVE
        this.hoverX := 0
        this.hoverY := 0
        this.tipShown := false
        this.captured := false        ; the window holds the mouse (SetCapture) for the pointer (_Sync)
        this.statusText := ""
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
        dpi := A_ScreenDPI > 0 ? A_ScreenDPI : 96
        width := Round((right - left) * EditorWindow.SIZE_SHARE * 96 / dpi)
        height := Round((bottom - top) * EditorWindow.SIZE_SHARE * 96 / dpi)
        this.win := UiWindow("editor", "Editor", width, height)
        this.hwnd := this.win.Hwnd
        this.status := this.win.Gui.Add("StatusBar")
        this.win.onClose := () => this.role.CloseEditor()
        this.iconState := ""          ; the state of the icon in use (SetIcon)
        this.icons := []              ; the icon handles of the window (big, small), freed when replaced or closed
        this.paintFn := (wParam, lParam, msg, hwnd) => this._OnPaint(hwnd)
        this.eraseFn := (wParam, lParam, msg, hwnd) => this._OnErase(hwnd)
        this.sizeFn := (wParam, lParam, msg, hwnd) => this._OnSize(lParam, hwnd)
        this.frameFn := () => this._Frame()
        this.hoverFn := () => this._HoverTimer()
        this.keyFn := (wParam, lParam, msg, hwnd) => this._OnKey(wParam, hwnd)
        this.activateFn := (wParam, lParam, msg, hwnd) => this._OnActivate(wParam, hwnd)
        this.mouseFns := Map(
            EditorWindow.WM_MOUSEMOVE, (wParam, lParam, msg, hwnd) => this._OnMove(wParam, lParam, hwnd),
            EditorWindow.WM_LBUTTONDOWN, (wParam, lParam, msg, hwnd) => this._OnDown("left", lParam, hwnd),
            EditorWindow.WM_LBUTTONUP, (wParam, lParam, msg, hwnd) => this._OnUp("left", lParam, hwnd),
            EditorWindow.WM_LBUTTONDBLCLK, (wParam, lParam, msg, hwnd) => this._OnDown("left", lParam, hwnd),
            EditorWindow.WM_RBUTTONDOWN, (wParam, lParam, msg, hwnd) => this._OnDown("right", lParam, hwnd),
            EditorWindow.WM_RBUTTONUP, (wParam, lParam, msg, hwnd) => this._OnUp("right", lParam, hwnd),
            EditorWindow.WM_MOUSEWHEEL, (wParam, lParam, msg, hwnd) => this._OnWheel(wParam, lParam, hwnd),
            EditorWindow.WM_MOUSELEAVE, (wParam, lParam, msg, hwnd) => this._OnLeave(hwnd))
        OnMessage(EditorWindow.WM_PAINT, this.paintFn)
        OnMessage(EditorWindow.WM_ERASEBKGND, this.eraseFn)
        OnMessage(EditorWindow.WM_SIZE, this.sizeFn)
        OnMessage(EditorWindow.WM_KEYDOWN, this.keyFn)
        OnMessage(EditorWindow.WM_ACTIVATE, this.activateFn)
        for msg, fn in this.mouseFns
            OnMessage(msg, fn)
        this.Refresh()
    }

    ; Shows the window (at its remembered place, or centred) and asks for the first frame. Returns at once.
    Show() {
        this.win.Show()
        this.Request()
    }

    ; The window comes to the front: shown when hidden, restored when minimized (cmd.editor.show).
    Raise() {
        if (!this.win.Visible)
            this.Show()
        else if (WinGetMinMax(this.hwnd) = -1)
            WinRestore(this.hwnd)
        try WinActivate(this.hwnd)
    }

    Visible => this.win.Visible

    ; The menu bar of the window (EditorMenus.Bar, WI-0102): set before the first Show; the bar takes a line of the window, the
    ; canvas follows it at the next WM_SIZE. A new bar replaces the old one (a language change).
    SetMenuBar(bar) {
        if (!this.closed)
            this.win.Gui.MenuBar := bar
    }

    ; The icon of the window is the icon of the flow state (REQ-EDT-230, the same as the tray icon): big and small, at the DPI of
    ; the window. The handles are freed when the icon changes and at Close. A state that is already shown does nothing.
    SetIcon(state) {
        if (this.closed || state = this.iconState)
            return
        dpi := DllCall("user32\GetDpiForWindow", "ptr", this.hwnd, "uint")
        if (dpi <= 0)
            dpi := 96
        file := EditorTray.IconFile(state)
        big := EditorWindow._LoadIcon(file, Round(32 * dpi / 96))
        small := EditorWindow._LoadIcon(file, Round(16 * dpi / 96))
        if (big = 0 || small = 0) {
            this.role._Log("a0", "editor", "window icon not loaded: " file)
            EditorWindow._DestroyIcon(big)
            EditorWindow._DestroyIcon(small)
            return
        }
        this.iconState := state
        WM_SETICON := 0x0080
        DllCall("user32\SendMessageW", "ptr", this.hwnd, "uint", WM_SETICON, "ptr", 1, "ptr", big)     ; ICON_BIG
        DllCall("user32\SendMessageW", "ptr", this.hwnd, "uint", WM_SETICON, "ptr", 0, "ptr", small)   ; ICON_SMALL
        this._FreeIcons()
        this.icons := [big, small]
    }

    static _LoadIcon(file, size) => LoadPicture(file, "w" size " h" size, &imageType)

    static _DestroyIcon(handle) {
        if (handle)
            DllCall("user32\DestroyIcon", "ptr", handle)
    }

    _FreeIcons() {
        for handle in this.icons
            EditorWindow._DestroyIcon(handle)
        this.icons := []
    }

    ; The question of a flow command (EditorFlowOps.ask): a dialog of the window, answered once by done(yes).
    Confirm(kind, args, done) {
        keys := EditorFlowOps.ASK[kind]
        opened := UiDialogs.Confirm(this.hwnd, keys[1], keys[2], [["yes", "Yes"], ["no", "No"]]
            , (answered, id) => done(answered && id = "yes"), args*)
        if (!opened)
            done(false)
    }

    ; The class list of a new element (EditorAdd, WI-0099): the tree dialog of the kind; done(classId) once, "" for a cancel.
    ; A dialog that cannot open answers "" at once.
    Choose(kind, groups, done) {
        opened := UiDialogs.Tree(this.hwnd, "Create new " kind, "Choose the class of the new element", groups
            , (ok, id) => done(ok ? id : ""))
        if (!opened)
            done("")
    }

    ; A question of a connection (EditorConnect, WI-0100): a dialog with one button per id; done(id) once, "" for a cancel or
    ; a dialog that cannot open. buttons: Array of [id, labelKey].
    Pick(titleKey, textKey, buttons, done) {
        opened := UiDialogs.Confirm(this.hwnd, titleKey, textKey, buttons, (answered, id) => done(answered ? id : ""))
        if (!opened)
            done("")
    }

    ; The title: "AutoHotFlow <Editor> - <flow name>" (the flow ID while the name is not known).
    Refresh() {
        if (this.closed)
            return
        name := this.role.model.name
        if (name = "")
            name := this.role.flowId
        this.win.Gui.Title := "AutoHotFlow " Lang("Editor") " - " name
    }

    ; A frame is wanted: the scene changed. One frame per FRAME_MS at most; the timer draws it.
    Request() {
        if (this.closed || this.scheduled)
            return
        this.scheduled := true
        wait := Max(1, EditorWindow.FRAME_MS - (Time.NowMs() - this.lastFrameMs))   ; SetTimer(fn, -0) would switch it off
        SetTimer(this.frameFn, -wait)
    }

    ; The timer: draws the scene into the back buffer when it is new, then the window copies it (WM_PAINT).
    _Frame() {
        this.scheduled := false
        if (this.closed || this.canvas = "")
            return
        sc := this.role.model.CurrentScene()
        if (sc = "" || sc.Version = this.lastVersion)
            return
        this.lastFrameMs := Time.NowMs()
        try {
            this.role._Renderer().Draw(sc, this.canvas)
        } catch as e {
            this.role._Log("a0", "editor", "frame failed: " Type(e) ": " e.Message)
            return
        }
        this.lastVersion := sc.Version
        this.role.model.NoteFrame()
        this.frames += 1
        DllCall("user32\InvalidateRect", "ptr", this.hwnd, "ptr", 0, "int", 0)
    }

    ; WM_PAINT: the back buffer goes to the window. Other windows of the process are left to Windows.
    _OnPaint(hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        ps := Buffer(72, 0)
        hdc := DllCall("user32\BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")
        try {
            if (IsObject(this.canvas))
                this.canvas.CopyToDc(hdc, 0, 0)
        } finally {
            DllCall("user32\EndPaint", "ptr", hwnd, "ptr", ps)
        }
        return 0
    }

    ; WM_ERASEBKGND: the back buffer covers the client area, so the background is not erased (no flicker).
    _OnErase(hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        return 1
    }

    ; WM_SIZE: a new back buffer of the client size and DPI; the view takes the size, the next frame is drawn.
    _OnSize(lParam, hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        w := lParam & 0xFFFF
        h := (lParam >> 16) & 0xFFFF
        if (w < 1 || h < 1)
            return
        ; the status bar takes the bottom of the client area (it lays itself out on the WM_SIZE it is sent here)
        DllCall("user32\SendMessageW", "ptr", this.status.Hwnd, "uint", EditorWindow.WM_SIZE, "ptr", 0, "ptr", 0)
        WinGetPos(, , , &barH, "ahk_id " this.status.Hwnd)
        h := Max(1, h - barH)
        dpi := DllCall("user32\GetDpiForWindow", "ptr", hwnd, "uint")
        if (dpi <= 0)
            dpi := 96
        if (IsObject(this.canvas) && this.canvas.width = w && this.canvas.height = h) {
            if (this.role.model.view.Dpi != dpi) {          ; the same pixels at another DPI (the window moved screens)
                this.role.model.SetCanvas(w, h, dpi)
                this.Request()
            }
            return
        }
        try {
            fresh := GdipCanvas(w, h)
        } catch as e {
            this.role._Log("a0", "editor", "back buffer not made: " Type(e) ": " e.Message)
            return
        }
        if (IsObject(this.canvas))
            this.canvas.Destroy()
        this.canvas := fresh
        this.role.model.SetCanvas(w, h, dpi)
        this.Request()
    }

    ; The status bar shows the view and the number of elements (FlowStatus). Called when the view or the flow changes; the
    ; text is set only when it changed.
    UpdateStatus() {
        if (this.closed)
            return
        text := this.role.model.StatusText()
        if (text = this.statusText)
            return
        this.statusText := text
        this.status.SetText(text)
    }

    ; WM_MOUSEMOVE: the pointer follows the mouse while it holds it (a drag, a rectangle, the view); otherwise the tooltip
    ; waits for the rest. wParam tells the buttons that are down (MK_LBUTTON 0x1, MK_RBUTTON 0x2).
    _OnMove(wParam, lParam, hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        pt := EditorWindow._Point(lParam)
        if (!this.tracking)
            this._TrackLeave()
        pointer := this.role.pointer
        if (pointer.Holding) {
            held := (wParam & 0x1) ? "left" : ((wParam & 0x2) ? "right" : "")
            pointer.Move(pt[1], pt[2], held)
            this._Sync()                               ; the drag may have ended (a lost button, or a cancel)
            return 0
        }
        this._HideTip()
        this.hoverX := pt[1]
        this.hoverY := pt[2]
        SetTimer(this.hoverFn, -EditorWindow.HOVER_MS)    ; setting it again restarts the wait
        return 0
    }

    ; WM_LBUTTONDOWN / WM_RBUTTONDOWN: the pointer gets the press. It holds the mouse while it works (SetCapture).
    _OnDown(button, lParam, hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        pt := EditorWindow._Point(lParam)
        this._HideTip()
        pointer := this.role.pointer
        pointer.Down(button, pt[1], pt[2], GetKeyState("Ctrl", "P"))
        this._Sync()
        return 0
    }

    ; WM_LBUTTONUP / WM_RBUTTONUP: the pointer ends its click or drag; the capture goes with it.
    _OnUp(button, lParam, hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        pt := EditorWindow._Point(lParam)
        pointer := this.role.pointer
        pointer.Up(button, pt[1], pt[2])
        this._Sync()
        return 0
    }

    ; WM_ACTIVATE: the window became active. The clipboard may have changed in another program, so the paste state of the
    ; menu bar is checked again (EditorMenus.Refresh). wParam's low word is 0 when the window was deactivated.
    _OnActivate(wParam, hwnd) {
        if (hwnd != this.hwnd || this.closed || (wParam & 0xFFFF) = 0)
            return
        try this.role.menus.Refresh()
    }

    ; WM_KEYDOWN of this window: the key table (EditorKeys) decides; a key it does not know goes on to Windows.
    _OnKey(vk, hwnd) {
        if (hwnd != this.hwnd || this.closed)
            return
        key := EditorKeys.KeyOf(vk)
        if (key = "")
            return
        name := EditorKeys.Name(key, GetKeyState("Ctrl", "P"), GetKeyState("Shift", "P"))
        if (EditorKeys.Handle(this.role.pointer, name, this._MouseAt())) {
            this._Sync()                               ; Esc may have ended a drag or a placing: it takes no mouse message
            return 0
        }
    }

    ; The canvas pixel under the mouse, or "" when the mouse is not over the canvas (a paste goes under the mouse, WI-0101).
    _MouseAt() {
        if (!IsObject(this.canvas))
            return ""
        pt := Buffer(8, 0)
        DllCall("user32\GetCursorPos", "ptr", pt)
        DllCall("user32\ScreenToClient", "ptr", this.hwnd, "ptr", pt)
        x := NumGet(pt, 0, "int")
        y := NumGet(pt, 4, "int")
        view := this.role.model.view
        if (x < 0 || y < 0 || x >= view.Width || y >= view.Height)
            return ""
        return [x, y]
    }

    ; The mouse is captured while the pointer holds it (EditorPointer.Holding): the capture is taken when the pointer starts to
    ; hold it and released when it lets go, by whatever way (a release, a key, a lost button). Called after every call of
    ; the pointer.
    _Sync() {
        want := this.role.pointer.Holding
        if (want && !this.captured) {
            DllCall("user32\SetCapture", "ptr", this.hwnd)
            this.captured := true
        } else if (!want && this.captured) {
            DllCall("user32\ReleaseCapture")
            this.captured := false
        }
    }

    ; WM_MOUSEWHEEL goes to the focused window, so it is taken when the pointer is over the canvas, whichever window got it.
    ; One notch zooms one step (EditorView.ZoomStep) at the pointer.
    _OnWheel(wParam, lParam, hwnd) {
        if (this.closed)
            return
        ; a wheel over the settings window scrolls that window, not the flow beneath it (F-0169)
        MouseGetPos(, , &under)
        if (IsObject(this.role.settingsWindow) && this.role.settingsWindow.Owns(under))
            return
        delta := (wParam >> 16) & 0xFFFF
        if (delta >= 0x8000)
            delta -= 0x10000
        if (delta = 0)
            return
        screen := EditorWindow._Point(lParam)          ; screen pixels for this message
        pt := Buffer(8, 0)
        NumPut("int", screen[1], pt, 0)
        NumPut("int", screen[2], pt, 4)
        DllCall("user32\ScreenToClient", "ptr", this.hwnd, "ptr", pt)
        cx := NumGet(pt, 0, "int")
        cy := NumGet(pt, 4, "int")
        model := this.role.model
        view := model.view
        if (cx < 0 || cy < 0 || cx >= view.Width || cy >= view.Height)
            return
        model.ChangeView(view.ZoomStep(delta > 0 ? 1 : -1, cx, cy))
        return 0
    }

    _OnLeave(hwnd) {
        if (hwnd != this.hwnd)
            return
        this.tracking := false
        this._HideTip()
        SetTimer(this.hoverFn, 0)
        return 0
    }

    ; The mouse has rested: the tooltip of what lies under it, if anything, next to the pointer.
    _HoverTimer() {
        if (this.closed || this.role.pointer.Holding)
            return
        MouseGetPos(&mx, &my, &under)
        if (under != this.hwnd)
            return
        hit := this._HitAt(this.hoverX, this.hoverY)
        sc := this.role.model.CurrentScene()
        if (!IsObject(sc) || hit = "")
            return
        text := FlowTooltip.Text(sc, hit, this.role.model.messages)
        if (text = "")
            return
        ToolTip(text, mx + 16, my + 16)
        this.tipShown := true
    }

    _HideTip() {
        if (this.tipShown) {
            ToolTip()
            this.tipShown := false
        }
    }

    ; The item under a client pixel of the canvas (FlowHit or "").
    _HitAt(cx, cy) {
        model := this.role.model
        sc := model.CurrentScene()
        if (!IsObject(sc))
            return ""
        pt := model.view.ToFlow(cx, cy)
        return FlowHitTest.At(sc, pt[1], pt[2])
    }

    ; TrackMouseEvent with TME_LEAVE: the next WM_MOUSELEAVE of the window (the tooltip hides then).
    _TrackLeave() {
        size := (A_PtrSize = 8) ? 24 : 16
        buf := Buffer(size, 0)
        NumPut("uint", size, buf, 0)
        NumPut("uint", 0x2, buf, 4)
        NumPut("ptr", this.hwnd, buf, 8)
        DllCall("user32\TrackMouseEvent", "ptr", buf)
        this.tracking := true
    }

    ; The client point of a mouse message (lParam): x and y, signed.
    static _Point(lParam) {
        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF
        return [x >= 0x8000 ? x - 0x10000 : x, y >= 0x8000 ? y - 0x10000 : y]
    }

    ; Stops the frames and the messages, frees the back buffer and destroys the window. A second call does nothing.
    Close() {
        if (this.closed)
            return
        this.closed := true
        this.scheduled := false
        SetTimer(this.frameFn, 0)
        SetTimer(this.hoverFn, 0)
        this._HideTip()
        if (this.captured) {
            DllCall("user32\ReleaseCapture")
            this.captured := false
        }
        OnMessage(EditorWindow.WM_PAINT, this.paintFn, 0)
        OnMessage(EditorWindow.WM_ERASEBKGND, this.eraseFn, 0)
        OnMessage(EditorWindow.WM_SIZE, this.sizeFn, 0)
        OnMessage(EditorWindow.WM_KEYDOWN, this.keyFn, 0)
        OnMessage(EditorWindow.WM_ACTIVATE, this.activateFn, 0)
        for msg, fn in this.mouseFns
            OnMessage(msg, fn, 0)
        if (IsObject(this.canvas)) {
            this.canvas.Destroy()
            this.canvas := ""
        }
        this.win.Close()
        this._FreeIcons()
    }
}
