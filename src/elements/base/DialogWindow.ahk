#Requires AutoHotkey v2.0
#Include ..\..\core\Lang.ahk

; The real windows of the dialog elements (WI-0056; ELEMENT-API-V2 3.3 and 3.4; REQ-ELM-270, REQ-DBG-060, REQ-USE-090).
; Only the product's Dialogs.Real class uses them (Dialogs.ahk). A dialog element runs in a worker (ARCHITECTURE 2.3),
; so the windows may block the thread until the user answers; the engine never shows them.
;
; Both windows return only when they have an answer: a button, the close button or Escape, the timeout of the
; element (Message) or nothing else. A stop of the instance ends the worker process (ARCHITECTURE 6.4), so there is no
; cancel path here.
class DialogWindow {
    static POLL_MS := 50         ; the answer is looked at this often while the window is open
    static MARGIN := 12          ; space between the controls and the edge of the window, in pixels
    static BUTTON_W := 110
    static BUTTON_H := 30
    static _dpiSet := false

    ; The window of Dialogs.Window: spec is a Map (title, text, buttons, width, height, timeoutMs, defaultId).
    ; Returns the id of the pressed button, "close" or "timeout".
    static Message(spec) {
        this._EnableDpi()
        m := this.MARGIN
        width := Max(spec.Get("width", 300), 200)
        height := Max(spec.Get("height", 200), 120)
        buttons := spec.Get("buttons", [])
        textW := width - 2 * m
        textH := Max(height - this.BUTTON_H - 3 * m, 20)
        btnsW := buttons.Length * (this.BUTTON_W + m) - m
        x := m + Max(textW - btnsW, 0)
        y := m + textH + m
        res := Map("value", "")
        g := Gui("-DPIScale", spec.Get("title", ""))
        lay := this._NewLayout(g, width, height)
        this._Place(lay, g.AddText(, spec.Get("text", "")), m, m, textW, textH)
        defaultId := spec.Get("defaultId", "")
        for button in buttons {
            ctl := g.AddButton(button["id"] = defaultId ? "Default" : "", button["label"])
            this._Place(lay, ctl, x, y, this.BUTTON_W, this.BUTTON_H)
            ctl.OnEvent("Click", this._Pick(res, button["id"]))
            x += this.BUTTON_W + m
        }
        g.OnEvent("Close", this._Pick(res, "close"))
        g.OnEvent("Escape", this._Pick(res, "close"))
        timer := this._Pick(res, "timeout")
        timeoutMs := spec.Get("timeoutMs", 0)
        if (timeoutMs > 0)
            SetTimer(timer, -timeoutMs)
        this._Show(lay)
        return this._Wait(res, g, timer, lay)
    }

    ; The debug window of REQ-DBG-060. view: Rows(), Text(name, convert), Type(name), Write(name, text, asObject, convert),
    ; Delete(name) and ReadOnly (lib/DebugOps.ahk of the package Default). Returns "yes", "no" or "close". In the read-only
    ; mode (REQ-USE-080) the variables are only shown: the change and delete buttons are off, the Yes button is "Close".
    static Debug(view) {
        this._EnableDpi()
        res := Map("value", "")
        g := Gui("-DPIScale", Lang("Debug dialog"))
        lay := this._NewLayout(g, 690, 430)
        c := Map("names", [], "name", "", "view", view)
        this._Place(lay, g.AddText(, Lang("Variable list")), 12, 12, 260, 20)
        c["list"] := this._Place(lay, g.AddListBox(), 12, 32, 260, 330)
        refresh := this._Place(lay, g.AddButton(, Lang("Update")), 12, 370, 110, 28)
        this._Place(lay, g.AddText(, Lang("Type and value")), 290, 12, 380, 20)
        c["type"] := this._Place(lay, g.AddDropDownList("Disabled", [Lang("Normal"), Lang("Object")]), 290, 32, 130)
        c["convert"] := this._Place(lay, g.AddCheckBox(, Lang("Convert special characters")), 430, 36, 240, 20)
        c["edit"] := this._Place(lay, g.AddEdit("Multi WantReturn"), 290, 60, 380, 230)
        c["status"] := this._Place(lay, g.AddText(), 290, 298, 380, 28)
        c["change"] := this._Place(lay, g.AddButton("Disabled", Lang("Change value")), 290, 332, 180, 30)
        c["delete"] := this._Place(lay, g.AddButton("Disabled", Lang("Delete variable")), 480, 332, 190, 30)
        yesBtn := this._Place(lay, g.AddButton(, view.ReadOnly ? Lang("Close") : Lang("Yes")), 290, 380, 100, 30)
        noBtn := this._Place(lay, g.AddButton(, Lang("No")), 400, 380, 100, 30)
        if (view.ReadOnly) {
            noBtn.Visible := false
            c["change"].Visible := false
            c["delete"].Visible := false
        }
        refresh.OnEvent("Click", (*) => DialogWindow._Guard(c, "_Fill", c["name"]))
        c["list"].OnEvent("Change", (*) => DialogWindow._Guard(c, "_Select"))
        c["convert"].OnEvent("Click", (*) => DialogWindow._Guard(c, "_ShowText"))
        c["change"].OnEvent("Click", (*) => DialogWindow._Guard(c, "_Write"))
        c["delete"].OnEvent("Click", (*) => DialogWindow._Guard(c, "_Delete"))
        yesBtn.OnEvent("Click", this._Pick(res, view.ReadOnly ? "close" : "yes"))
        noBtn.OnEvent("Click", this._Pick(res, "no"))
        g.OnEvent("Close", this._Pick(res, "close"))
        g.OnEvent("Escape", this._Pick(res, "close"))
        this._Guard(c, "_Fill", "")
        this._Show(lay)
        return this._Wait(res, g, "", lay)
    }

    ; Runs one handler of the debug window (named by name) from a GUI event or from the start. A request to the engine
    ; that fails (timeout, the instance has ended: ElementError, WorkerContext) must not end the thread inside the event:
    ; the error goes to the status line of the window, and the window stays usable.
    static _Guard(c, name, args*) {
        try {
            DialogWindow.%name%(c, args*)
        } catch as e {
            c["status"].Value := "Error: " e.Message
        }
    }

    ; Fills the list of the variables from view.Rows(); keepName is selected again when it is still there.
    static _Fill(c, keepName) {
        view := c["view"]
        items := []
        names := []
        for row in view.Rows() {
            items.Push(row["text"])
            names.Push(row["name"])
        }
        c["names"] := names
        c["list"].Delete()
        if (items.Length > 0)
            c["list"].Add(items)
        index := 0
        for i, name in names {
            if (name != "" && name = keepName)
                index := i
        }
        if (index > 0)
            c["list"].Choose(index)
        this._Select(c)
    }

    ; The selected variable: its type and its text in the edit field (nothing for a separator line).
    static _Select(c) {
        index := c["list"].Value
        names := c["names"]
        name := (index >= 1 && index <= names.Length) ? names[index] : ""
        c["name"] := name
        view := c["view"]
        c["status"].Value := ""
        if (name = "") {
            c["edit"].Value := ""
            c["type"].Choose(1)
            c["type"].Enabled := false
            c["change"].Enabled := false
            c["delete"].Enabled := false
            return
        }
        c["type"].Choose(view.Type(name) = "object" ? 2 : 1)
        c["type"].Enabled := !view.ReadOnly
        c["change"].Enabled := !view.ReadOnly
        c["delete"].Enabled := !view.ReadOnly
        this._ShowText(c)
    }

    ; Shows the value of the selected variable again, with or without the conversion of special characters.
    static _ShowText(c) {
        if (c["name"] = "")
            return
        c["edit"].Value := c["view"].Text(c["name"], c["convert"].Value)
    }

    ; "Change value": the type and the text of the edit field become the value of the variable. A text that is not
    ; readable as an object stays in the field with the error in the status line, and the variable is not changed.
    static _Write(c) {
        if (c["name"] = "")
            return
        err := c["view"].Write(c["name"], c["edit"].Value, c["type"].Value = 2, c["convert"].Value)
        c["status"].Value := err
        if (err = "")
            this._Fill(c, c["name"])
    }

    static _Delete(c) {
        if (c["name"] = "")
            return
        c["view"].Delete(c["name"])
        this._Fill(c, "")
    }

    ; Returns a function that sets the answer once (the first one wins: a button, then the close of the window).
    static _Pick(res, value) => (*) => DialogWindow._Set(res, value)

    static _Set(res, value) {
        if (res["value"] = "")
            res["value"] := value
    }

    ; Waits for the answer in res, then removes the timer and the window. The wait runs only in a worker (ELEMENT-API-V2 3.3).
    static _Wait(res, g, timer, lay) {
        try {
            while (res["value"] = "")
                Sleep(this.POLL_MS)  ; arch-ok: blocking the dialog wait is allowed in a worker only (ELEMENT-API-V2 3.3)
        } finally {
            if (IsObject(timer))
                SetTimer(timer, 0)
            OnMessage(0x02E0, lay["cb"], 0)
            g.Destroy()
            if (lay["font"])
                DllCall("gdi32\DeleteObject", "ptr", lay["font"])
        }
        return res["value"]
    }

    ; Declares the process as per-monitor DPI aware for the windows of this thread, so they are drawn sharp on a
    ; display with a scaling above 100 % (REQ-USE-090). The sizes are scaled by the layout below.
    static _EnableDpi() {
        if (this._dpiSet)
            return
        this._dpiSet := true
        try DllCall("user32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")   ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    }

    ; The layout of a window. All positions and sizes are given in pixels at 100 % (96 dpi) and are scaled by the DPI of the
    ; window: at the start, and again whenever Windows reports another DPI (monitor change, scaling changed while the window
    ; is open). The windows are created with -DPIScale: otherwise AutoHotkey scales every coordinate again with the DPI that the
    ; process had at its start, and the sizes are wrong whenever that differs from the DPI of the window (HOW-TO gui-and-hotkeys).
    static _NewLayout(g, width, height) {
        lay := Map("g", g, "items", [], "w", width, "h", height, "dpi", 96, "font", 0)
        ; WM_DPICHANGED. A Gui has no OnMessage in v2, so the global one is used; it is removed again in _Wait.
        lay["cb"] := (wParam, lParam, msg, hwnd) => DialogWindow._OnDpiChanged(lay, wParam, lParam, hwnd)
        OnMessage(0x02E0, lay["cb"])
        return lay
    }

    ; Registers a control with its place; h is left out for a control whose height is fixed by Windows (drop-down list).
    static _Place(lay, ctl, x, y, w, h := "") {
        lay["items"].Push([ctl, x, y, w, h])
        return ctl
    }

    static _Scale(lay, n) => Round(n * lay["dpi"] / 96)

    ; Moves the controls and sets the font for the DPI dpi (0: the DPI of the window).
    static _Apply(lay, dpi := 0) {
        if (dpi <= 0)
            dpi := DllCall("user32\GetDpiForWindow", "ptr", lay["g"].Hwnd, "uint")
        lay["dpi"] := dpi > 0 ? dpi : 96
        oldFont := lay["font"]
        lay["font"] := DllCall("gdi32\CreateFontW", "int", -Round(9 * lay["dpi"] / 72), "int", 0, "int", 0, "int", 0
            , "int", 400, "uint", 0, "uint", 0, "uint", 0, "uint", 1, "uint", 0, "uint", 0, "uint", 5, "uint", 0
            , "str", "Segoe UI", "ptr")
        for it in lay["items"] {
            ctl := it[1]
            if (it[5] = "")
                ctl.Move(this._Scale(lay, it[2]), this._Scale(lay, it[3]), this._Scale(lay, it[4]))
            else
                ctl.Move(this._Scale(lay, it[2]), this._Scale(lay, it[3]), this._Scale(lay, it[4]), this._Scale(lay, it[5]))
            SendMessage(0x30, lay["font"], 1, ctl)   ; WM_SETFONT
        }
        if (oldFont)
            DllCall("gdi32\DeleteObject", "ptr", oldFont)
    }

    ; Scales the layout for the DPI of the window and shows the window centered with the scaled client size. The outer size
    ; is set by _Fit: the size that Show("w.. h..") computes uses the title bar and frame of the DPI that the process had at its
    ; start (too small at 225 % after a start at 100 %, too big the other way round; manual check 3).
    static _Show(lay) {
        this._Apply(lay)
        g := lay["g"]
        g.Show("Hide Center w" this._Scale(lay, lay["w"]) " h" this._Scale(lay, lay["h"]))
        ; Show computes the outer size itself, so _Fit comes after it, and the window is centered again on its old center.
        ; The window stays hidden until it has its final size and position (no flicker). Every later Show of the Gui, even
        ; one without options, sizes the window again with the frame of the start DPI, so the window is shown by Windows.
        g.GetPos(&x, &y, &w, &h)
        this._Fit(lay)
        g.GetPos(, , &newW, &newH)
        g.Move(x + w // 2 - newW // 2, y + h // 2 - newH // 2)
        DllCall("user32\ShowWindow", "ptr", g.Hwnd, "int", 5)   ; SW_SHOW
        WinActivate(g.Hwnd)
    }

    ; Sets the outer size of the window so that its client area is the scaled size of the layout, with the title bar and frame
    ; of the DPI dpi. x and y are the new position (a position of 0 is a position: pass both or none).
    static _Fit(lay, x?, y?) {
        g := lay["g"]
        rc := Buffer(16, 0)
        NumPut("int", this._Scale(lay, lay["w"]), "int", this._Scale(lay, lay["h"]), rc, 8)
        DllCall("user32\AdjustWindowRectExForDpi", "ptr", rc, "uint", WinGetStyle(g.Hwnd), "int", false
            , "uint", WinGetExStyle(g.Hwnd), "uint", lay["dpi"])
        flags := 0x14   ; SWP_NOZORDER | SWP_NOACTIVATE
        if (!IsSet(x))
            flags |= 0x2   ; SWP_NOMOVE
        DllCall("user32\SetWindowPos", "ptr", g.Hwnd, "ptr", 0, "int", x ?? 0, "int", y ?? 0
            , "int", NumGet(rc, 8, "int") - NumGet(rc, 0, "int"), "int", NumGet(rc, 12, "int") - NumGet(rc, 4, "int"), "uint", flags)
    }

    ; WM_DPICHANGED: the new DPI is in the low word of wParam, lParam points to the position that Windows suggests. The window
    ; gets the scaled client size plus the title bar and frame of the new DPI, so that nothing is cut off (returning 0: Windows
    ; does not resize it again). An error here must not end the thread inside the message.
    static _OnDpiChanged(lay, wParam, lParam, hwnd) {
        if (hwnd != lay["g"].Hwnd)
            return   ; another window of this thread: not handled, Windows goes on as usual
        try {
            dpi := wParam & 0xFFFF
            this._Apply(lay, dpi)
            this._Fit(lay, NumGet(lParam, 0, "int"), NumGet(lParam, 4, "int"))
        }
        return 0
    }
}
