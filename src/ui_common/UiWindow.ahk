#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include UiTexts.ahk

; The window base of the UI roles (REQ-USE-090, REQ-USE-040, REQ-LNG-010; WI-0069). A window is a Gui with the layout of
; GuiLayout (sharp at every scaling, the sizes at 100 %), its texts are registered in UiTexts, and its position and size
; are remembered per window name while the process runs. The remembered values are UI state of the process; where they
; are saved (a file of the storage role or the settings) is decided in WI-0073.
;
; A window is never shown by the message path of a role: Show returns at once, and the events of the controls are
; handled by the callbacks that the owner sets (rule 3, no blocking call).
;
; Usage: win := UiWindow("manager.flows", "titleKey", 600, 400)
;        win.Place(win.Gui.AddListView(...), 12, 12, 576, 300)   ; any control, positions at 100 %
;        UiTexts.Register(win.Hwnd, ctl, "Flow_list")            ; or win.Text(ctl, "Flow_list")
;        win.Show()  /  win.Close()
class UiWindow {
    static _memory := Map()   ; window name -> Map("x", "y", "w", "h"): outer position in pixels, client size at 100 %

    ; name: the key of the window (remembered); title: a Lang key; width and height at 100 % (a remembered size wins).
    __New(name, titleKey, width, height) {
        GuiLayout.EnableDpi()   ; before the first Gui of the thread
        this.name := name
        this._closed := false
        this._shown := false
        mem := UiWindow.Recall(name)
        if (mem != "") {
            width := mem["w"]
            height := mem["h"]
        }
        this.Gui := Gui("-DPIScale")
        this.Hwnd := this.Gui.Hwnd
        this.Gui.OnEvent("Close", (*) => this.Close())
        this.lay := GuiLayout.Create(this.Gui, width, height)
        UiTexts.Register(this.Hwnd, this.Gui, titleKey, "Title")
    }

    ; Places a control (positions and sizes at 100 %) and returns it.
    Place(ctl, x, y, w, h := "") => GuiLayout.Place(this.lay, ctl, x, y, w, h)

    ; Adds a text of key to a control (Text, or prop) and keeps it for a language change. Returns ctl.
    Text(ctl, key, prop := "Text", args*) => UiTexts.Register(this.Hwnd, ctl, key, prop, args*)

    ; Shows the window: at its remembered position, or centered. Returns at once.
    Show() {
        if (this._closed)
            return
        mem := UiWindow.Recall(this.name)
        if (mem != "")
            GuiLayout.Show(this.lay, mem["x"], mem["y"])
        else
            GuiLayout.Show(this.lay)
        this._shown := true
    }

    ; Remembers the position and the size, then removes the texts and the window. A second call does nothing.
    Close() {
        if (this._closed)
            return
        this.Remember()
        this._closed := true
        UiTexts.Forget(this.Hwnd)
        GuiLayout.Destroy(this.lay)
        this.Gui.Destroy()
    }

    ; Stores the current outer position and the client size (at 100 %) under the window name.
    Remember() {
        if (this._closed || !this._shown)   ; a window that was never shown has no position worth keeping
            return
        this.Gui.GetPos(&x, &y)
        this.Gui.GetClientPos(, , &cw, &ch)
        dpi := DllCall("user32\GetDpiForWindow", "ptr", this.Hwnd, "uint")
        if (dpi <= 0)
            dpi := 96
        UiWindow._memory[this.name] := Map("x", x, "y", y, "w", Round(cw * 96 / dpi), "h", Round(ch * 96 / dpi))
    }

    ; The remembered values of a window name, or "" when there are none.
    static Recall(name) => UiWindow._memory.Has(name) ? UiWindow._memory[name] : ""

    ; Forgets the remembered values of every window (tests).
    static ClearMemory() {
        UiWindow._memory := Map()
    }
}
