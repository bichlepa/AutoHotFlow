#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ClassicViewer.ahk

; The help window (WI-0111, E0098): a window of its own with a bar of two buttons, Back and Contents (the index), and the
; viewer below it. The window talks only to the viewer interface (HelpViewer): it knows nothing of the control. It is
; hidden, not destroyed, when the close box is pressed (as the manager's window), so the next page comes at once.
; Layout at 100 % (GuiLayout): the bar 12 to 40, the viewer from y 52 to the bottom, 12 pixels to the sides.
class HelpWindow {
    static WIDTH := 860
    static HEIGHT := 620
    static MARGIN := 12
    static BUTTON_W := 120
    static BUTTON_H := 28
    static VIEW_Y := 52

    __New(role) {
        this.role := role
        this.lastUrl := ""          ; the last location the viewer reported (HelpViewer.onLink)
        this.win := UiWindow("help.window", "Help_contents", HelpWindow.WIDTH, HelpWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        back := g.AddButton("", "")
        this.win.Place(back, HelpWindow.MARGIN, HelpWindow.MARGIN, HelpWindow.BUTTON_W, HelpWindow.BUTTON_H)
        this.win.Text(back, "Help_back")
        back.OnEvent("Click", (*) => this.viewer.Back())
        contents := g.AddButton("", "")
        this.win.Place(contents, HelpWindow.MARGIN + HelpWindow.BUTTON_W + HelpWindow.MARGIN, HelpWindow.MARGIN
            , HelpWindow.BUTTON_W, HelpWindow.BUTTON_H)
        this.win.Text(contents, "Help_index")
        contents.OnEvent("Click", (*) => this.role.ShowIndex())
        this.viewer := ClassicViewer(this)
        this.viewer.onLink := (url) => this._Followed(url)
        g.OnEvent("Size", (gui, mm, w, h) => this._OnSize(mm, w, h))
    }

    ; Shows the window and the generated page path in it (the window comes at its remembered place, UiWindow).
    Show(path) {
        this.win.Show()
        this.viewer.Navigate(path)
    }

    ; The viewer's control follows the client size of the window; a minimized window does not resize it.
    _OnSize(mm, w, h) {
        if (mm = -1 || w < 1 || h < 1)
            return
        x := GuiLayout.Scale(this.win.lay, HelpWindow.MARGIN)
        y := GuiLayout.Scale(this.win.lay, HelpWindow.VIEW_Y)
        if (w - 2 * x > 0 && h - y - x > 0)
            this.viewer.Resize(x, y, w - 2 * x, h - y - x)
    }

    _Followed(url) {
        this.lastUrl := url
    }
}
