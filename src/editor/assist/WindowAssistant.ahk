#Requires AutoHotkey v2.0
#Include ..\..\core\GuiLayout.ahk
#Include ..\..\core\Lang.ahk

; The window assistant of the element settings (WI-0110, v1 Get window information): a window of the editor process with the
; list of the windows. The timer (TICK ms) reads the window under the mouse; when the mouse has rested on another window for
; STILL ticks, that window's entry is selected (a window that is not in the list is added). OK takes the selected window: the
; values of the window identification (WindowIdent: Wintitle, ahk_class, ahk_exe; the excludes are emptied as in v1; ahk_id and
; ahk_pid only when the checkbox asks for them) go once to onDone. Cancel and Close give onDone an empty Map.
; Close stops the timer and destroys the window: no timer or hook stays behind. The owner disables the settings window while
; this one is open (EditorSettings). show false builds the window without showing it (the headless tests).
class WindowAssistant {
    static TICK := 200
    static STILL := 2
    static WIDTH := 480
    static MARGIN := 12
    static ROW := 6
    static LINE_H := 20
    static BUTTON_H := 30
    static BUTTON_W := 110
    static LIST_H := 200
    static DETAIL_H := 110

    __New(source, onDone) {
        this.source := source
        this.onDone := onDone
        this.gui := ""
        this.lay := ""
        this.list := ""
        this.details := ""
        this.importIds := ""
        this.hwnds := []
        this.followed := 0
        this.lastX := ""
        this.lastY := ""
        this.still := 0
        this.tickFn := (*) => this.Follow()
    }

    ; Builds the window, fills the list and starts following the mouse.
    Open(show := true) {
        m := WindowAssistant.MARGIN
        cw := WindowAssistant.WIDTH - 2 * m
        g := Gui("-DPIScale +AlwaysOnTop -MinimizeBox -MaximizeBox", Lang("Assist_window_title"))
        g.OnEvent("Close", (*) => this.Cancel())
        g.OnEvent("Escape", (*) => this.Cancel())
        this.gui := g
        this.lay := GuiLayout.Create(g, WindowAssistant.WIDTH, 100)
        y := m
        text := Lang("Assist_window_help")
        h := Max(GuiLayout.TextHeight(g, text, cw), WindowAssistant.LINE_H)
        GuiLayout.Place(this.lay, g.AddText("", text), m, y, cw, h)
        y += h + WindowAssistant.ROW
        this.list := g.AddListBox("", [])
        GuiLayout.Place(this.lay, this.list, m, y, cw, WindowAssistant.LIST_H)
        this.list.OnEvent("Change", (*) => this._Detail())
        y += WindowAssistant.LIST_H + WindowAssistant.ROW
        this.details := g.AddText("", "")
        GuiLayout.Place(this.lay, this.details, m, y, cw, WindowAssistant.DETAIL_H)
        y += WindowAssistant.DETAIL_H + WindowAssistant.ROW
        this.importIds := g.AddCheckbox("", Lang("Assist_unique_ids"))
        GuiLayout.Place(this.lay, this.importIds, m, y, cw, WindowAssistant.LINE_H)
        y += WindowAssistant.LINE_H + m
        bw := WindowAssistant.BUTTON_W
        bh := WindowAssistant.BUTTON_H
        ok := g.AddButton("Default", Lang("OK"))
        GuiLayout.Place(this.lay, ok, WindowAssistant.WIDTH - m - 2 * bw - m, y, bw, bh)
        ok.OnEvent("Click", (*) => this.Take())
        cancel := g.AddButton("", Lang("Cancel"))
        GuiLayout.Place(this.lay, cancel, WindowAssistant.WIDTH - m - bw, y, bw, bh)
        cancel.OnEvent("Click", (*) => this.Cancel())
        this.lay["h"] := y + bh + m
        this._Fill()
        if (show)
            GuiLayout.Show(this.lay)
        SetTimer(this.tickFn, WindowAssistant.TICK)
    }

    ; One tick: selects the window under the mouse when the mouse has rested on it (the mouse over this window does nothing).
    Follow() {
        if (!IsObject(this.gui))
            return
        pos := this.source.Mouse("Screen")
        hwnd := pos["hwnd"]
        if (hwnd = 0 || hwnd = this.gui.Hwnd)
            return
        if (pos["x"] != this.lastX || pos["y"] != this.lastY) {
            this.lastX := pos["x"]
            this.lastY := pos["y"]
            this.still := 0
            return
        }
        this.still++
        if (this.still < WindowAssistant.STILL || hwnd = this.followed)
            return
        this.followed := hwnd
        idx := this._IndexOf(hwnd)
        if (idx = 0)
            idx := this._Add(hwnd)
        this.list.Value := idx
        this._Detail()
    }

    ; OK: the window of the selected entry goes to onDone; the assistant closes. False when no entry is selected.
    Take() {
        if (!IsObject(this.gui))
            return false
        idx := this.list.Value
        if (idx < 1 || idx > this.hwnds.Length)
            return false
        info := this.source.WindowInfo(this.hwnds[idx])
        values := Map("Wintitle", info["title"], "ahk_class", info["class"], "ahk_exe", info["exe"]
            , "excludeTitle", "", "ExcludeText", "", "ahk_id", "", "ahk_pid", "")
        if (this.importIds.Value) {
            values["ahk_id"] := String(info["id"])
            values["ahk_pid"] := String(info["pid"])
        }
        this.Close()
        this.onDone.Call(values)
        return true
    }

    ; Cancel: nothing is taken; onDone gets an empty Map.
    Cancel() {
        if (!IsObject(this.gui))
            return
        this.Close()
        this.onDone.Call(Map())
    }

    ; Stops the timer and destroys the window. Idempotent.
    Close() {
        if (!IsObject(this.gui))
            return
        SetTimer(this.tickFn, 0)
        GuiLayout.Destroy(this.lay)
        this.gui.Destroy()
        this.gui := ""
        this.lay := ""
        this.list := ""
        this.details := ""
        this.importIds := ""
    }

    ; The windows of the list: every visible top-level window except this one.
    _Fill() {
        for hwnd in this.source.WindowList() {
            if (hwnd != this.gui.Hwnd)
                this._Add(hwnd)
        }
        if (this.hwnds.Length)
            this.list.Value := 1
        this._Detail()
    }

    _Add(hwnd) {
        info := this.source.WindowInfo(hwnd)
        this.hwnds.Push(hwnd)
        this.list.Add([info["class"] " " Chr(0x25BA) " " info["title"]])
        return this.hwnds.Length
    }

    _IndexOf(hwnd) {
        for index, h in this.hwnds {
            if (h = hwnd)
                return index
        }
        return 0
    }

    ; The details of the selected window in the text below the list.
    _Detail() {
        if (!IsObject(this.gui))
            return
        idx := this.list.Value
        if (idx < 1 || idx > this.hwnds.Length) {
            this.details.Text := ""
            return
        }
        info := this.source.WindowInfo(this.hwnds[idx])
        this.details.Text := Lang("Assist_title") ": " info["title"] "`n"
            . Lang("Assist_class") ": " info["class"] "`n"
            . Lang("Assist_process") ": " info["exe"] "`n"
            . Lang("Assist_window_id") ": " info["id"] "`n"
            . Lang("Assist_process_id") ": " info["pid"] "`n"
            . Lang("Assist_position") ": " info["x"] ", " info["y"] ", " info["w"] " x " info["h"]
    }
}
