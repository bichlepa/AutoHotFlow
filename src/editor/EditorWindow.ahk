#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Time.ahk
#Include ..\ui_common\UiWindow.ahk
#Include render\Renderer.ahk

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
; The window has no controls yet: the status bar, the zoom, the move and the tooltip come with WI-0090.
class EditorWindow {
    static FRAME_MS := 33
    static WM_PAINT := 0x000F
    static WM_ERASEBKGND := 0x0014
    static WM_SIZE := 0x0005
    static SIZE_SHARE := 0.9

    __New(role) {
        this.role := role
        this.canvas := ""             ; the back buffer, the size of the client area
        this.scheduled := false       ; a frame timer is set
        this.lastFrameMs := 0
        this.lastVersion := -1        ; the scene version of the last frame that was drawn
        this.frames := 0
        this.closed := false
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
        dpi := A_ScreenDPI > 0 ? A_ScreenDPI : 96
        width := Round((right - left) * EditorWindow.SIZE_SHARE * 96 / dpi)
        height := Round((bottom - top) * EditorWindow.SIZE_SHARE * 96 / dpi)
        this.win := UiWindow("editor", "Editor", width, height)
        this.hwnd := this.win.Hwnd
        this.win.onClose := () => this.role._OnWindowClose()
        this.paintFn := (wParam, lParam, msg, hwnd) => this._OnPaint(hwnd)
        this.eraseFn := (wParam, lParam, msg, hwnd) => this._OnErase(hwnd)
        this.sizeFn := (wParam, lParam, msg, hwnd) => this._OnSize(lParam, hwnd)
        this.frameFn := () => this._Frame()
        OnMessage(EditorWindow.WM_PAINT, this.paintFn)
        OnMessage(EditorWindow.WM_ERASEBKGND, this.eraseFn)
        OnMessage(EditorWindow.WM_SIZE, this.sizeFn)
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
        wait := Max(0, EditorWindow.FRAME_MS - (Time.NowMs() - this.lastFrameMs))
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
        if (IsObject(this.canvas) && this.canvas.width = w && this.canvas.height = h)
            return
        dpi := DllCall("user32\GetDpiForWindow", "ptr", hwnd, "uint")
        if (dpi <= 0)
            dpi := 96
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

    ; Stops the frames and the messages, frees the back buffer and destroys the window. A second call does nothing.
    Close() {
        if (this.closed)
            return
        this.closed := true
        SetTimer(this.frameFn, 0)
        OnMessage(EditorWindow.WM_PAINT, this.paintFn, 0)
        OnMessage(EditorWindow.WM_ERASEBKGND, this.eraseFn, 0)
        OnMessage(EditorWindow.WM_SIZE, this.sizeFn, 0)
        if (IsObject(this.canvas)) {
            this.canvas.Destroy()
            this.canvas := ""
        }
        this.win.Close()
    }
}
