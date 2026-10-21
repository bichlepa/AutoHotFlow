#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include ..\core\Log.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ClassicViewer.ahk
#Include WebView2Viewer.ahk

; The help window (WI-0111, E0098; WebView2 WI-0115, E0099): a window of its own with a bar of two buttons, Back and Contents
; (the index), and the viewer below it. The window talks only to the viewer interface (HelpViewer): it knows nothing of the
; control. It is hidden, not destroyed, when the close box is pressed (as the manager's window), so the next page comes at
; once.
;
; kind "webview2" starts the WebView2 viewer; when it cannot start, the window switches to the classic viewer and shows the
; page again (the role is told, so that it does not ask WebView2 again in this process).
; Layout at 100 % (GuiLayout): the bar 12 to 40, the viewer from y 52 to the bottom, 12 pixels to the sides.
class HelpWindow {
    static WIDTH := 860
    static HEIGHT := 620
    static MARGIN := 12
    static BUTTON_W := 120
    static BUTTON_H := 28
    static VIEW_Y := 52

    __New(role, kind := "classic") {
        this.role := role
        this.kind := ""                 ; the viewer's name ("classic" or "webview2") while a viewer is mounted
        this.viewer := ""               ; the HelpViewer (ClassicViewer or WebView2Viewer)
        this.lastUrl := ""              ; the last location the viewer reported (HelpViewer.onLink)
        this.lastPath := ""            ; the last page asked (the page a failed WebView2 viewer shows again)
        this.lastW := 0                 ; the client size of the window (Size event)
        this.lastH := 0
        this.win := UiWindow("help.window", "Help_contents", HelpWindow.WIDTH, HelpWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        back := g.AddButton("", "")
        this.win.Place(back, HelpWindow.MARGIN, HelpWindow.MARGIN, HelpWindow.BUTTON_W, HelpWindow.BUTTON_H)
        this.win.Text(back, "Help_back")
        back.OnEvent("Click", (*) => this._Back())
        contents := g.AddButton("", "")
        this.win.Place(contents, HelpWindow.MARGIN + HelpWindow.BUTTON_W + HelpWindow.MARGIN, HelpWindow.MARGIN
            , HelpWindow.BUTTON_W, HelpWindow.BUTTON_H)
        this.win.Text(contents, "Help_index")
        contents.OnEvent("Click", (*) => this.role.ShowIndex())
        g.OnEvent("Size", (gui, mm, w, h) => this._OnSize(mm, w, h))
        this._Mount(kind)
    }

    ; Shows the window and the generated page path in it (the window comes at its remembered place, UiWindow).
    Show(path) {
        this.lastPath := path
        this.win.Show()
        this.viewer.Navigate(path)
    }

    ; Releases the viewer and the window: the role uses this to change the viewer's kind.
    Close() {
        if (IsObject(this.viewer)) {
            this.viewer.Close()
            this.viewer := ""
        }
        this.win.Close()
    }

    ; Makes the viewer of a kind (the old one is closed) and places it at the current size.
    _Mount(kind) {
        if (IsObject(this.viewer)) {
            old := this.viewer
            this.viewer := ""
            old.Close()
        }
        if (kind = "webview2") {
            v := WebView2Viewer(this.win.Hwnd, this.role.dataDir "\WebView2", (reason) => this._WebView2Failed(reason))
            v.onLink := (url) => this._Followed(url)
            this.viewer := v
            this.kind := "webview2"
            v.Start()
        } else {
            v := ClassicViewer(this)
            v.onLink := (url) => this._Followed(url)
            this.viewer := v
            this.kind := "classic"
        }
        this._Layout()
    }

    ; The WebView2 viewer could not start: the classic viewer takes its place and shows the page asked last.
    _WebView2Failed(reason) {
        if (this.kind != "webview2")
            return                      ; a late report of a viewer that was replaced already
        this.role.WebView2Failed(reason)
        this._Mount("classic")
        if (this.lastPath != "")
            this.viewer.Navigate(this.lastPath)
    }

    _Back() {
        if (IsObject(this.viewer))
            this.viewer.Back()
    }

    ; The viewer follows the client size of the window; a minimized window does not resize it.
    _OnSize(mm, w, h) {
        if (mm = -1 || w < 1 || h < 1)
            return
        this.lastW := w
        this.lastH := h
        this._Layout()
    }

    _Layout() {
        if (!IsObject(this.viewer) || this.lastW < 1 || this.lastH < 1)
            return
        x := GuiLayout.Scale(this.win.lay, HelpWindow.MARGIN)
        y := GuiLayout.Scale(this.win.lay, HelpWindow.VIEW_Y)
        w := this.lastW
        h := this.lastH
        if (w - 2 * x > 0 && h - y - x > 0)
            this.viewer.Resize(x, y, w - 2 * x, h - y - x)
    }

    _Followed(url) {
        this.lastUrl := url
    }
}
