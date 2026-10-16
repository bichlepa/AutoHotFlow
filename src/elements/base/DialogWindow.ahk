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
        g := Gui(, spec.Get("title", ""))
        g.AddText("x" m " y" m " w" textW " h" textH, spec.Get("text", ""))
        defaultId := spec.Get("defaultId", "")
        for button in buttons {
            opt := "x" x " y" y " w" this.BUTTON_W " h" this.BUTTON_H
            if (button["id"] = defaultId)
                opt .= " Default"
            ctl := g.AddButton(opt, button["label"])
            ctl.OnEvent("Click", this._Pick(res, button["id"]))
            x += this.BUTTON_W + m
        }
        g.OnEvent("Close", this._Pick(res, "close"))
        g.OnEvent("Escape", this._Pick(res, "close"))
        timer := this._Pick(res, "timeout")
        timeoutMs := spec.Get("timeoutMs", 0)
        if (timeoutMs > 0)
            SetTimer(timer, -timeoutMs)
        g.Show("w" width " h" height)
        return this._Wait(res, g, timer)
    }

    ; The debug window of REQ-DBG-060. view: Rows(), Text(name, convert), Type(name), Write(name, text, asObject, convert),
    ; Delete(name) and ReadOnly (lib/DebugOps.ahk of the package Default). Returns "yes", "no" or "close". In the read-only
    ; mode (REQ-USE-080) the variables are only shown: the change and delete buttons are off, the Yes button is "Close".
    static Debug(view) {
        this._EnableDpi()
        res := Map("value", "")
        g := Gui(, Lang("Debug dialog"))
        c := Map("names", [], "name", "", "view", view)
        g.AddText("x12 y12 w260", Lang("Variable list"))
        c["list"] := g.AddListBox("x12 y32 w260 h330")
        refresh := g.AddButton("x12 y370 w110 h28", Lang("Update"))
        g.AddText("x290 y12 w380", Lang("Type and value"))
        c["type"] := g.AddDropDownList("x290 y32 w130 Disabled", [Lang("Normal"), Lang("Object")])
        c["convert"] := g.AddCheckBox("x430 y36 w240", Lang("Convert special characters"))
        c["edit"] := g.AddEdit("x290 y60 w380 h230 Multi WantReturn")
        c["status"] := g.AddText("x290 y298 w380 h28")
        c["change"] := g.AddButton("x290 y332 w180 h30 Disabled", Lang("Change value"))
        c["delete"] := g.AddButton("x480 y332 w190 h30 Disabled", Lang("Delete variable"))
        yesBtn := g.AddButton("x290 y380 w100 h30", view.ReadOnly ? Lang("Close") : Lang("Yes"))
        noBtn := g.AddButton("x400 y380 w100 h30", Lang("No"))
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
        g.Show("w690 h430")
        return this._Wait(res, g, "")
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
    static _Wait(res, g, timer) {
        try {
            while (res["value"] = "")
                Sleep(this.POLL_MS)  ; arch-ok: blocking the dialog wait is allowed in a worker only (ELEMENT-API-V2 3.3)
        } finally {
            if (IsObject(timer))
                SetTimer(timer, 0)
            g.Destroy()
        }
        return res["value"]
    }

    ; Declares the process as per-monitor DPI aware for the windows of this thread, so they are drawn sharp on a
    ; display with a scaling above 100 % (REQ-USE-090). Status: assumed, the owner checks it (WI-0056 manual check).
    static _EnableDpi() {
        if (this._dpiSet)
            return
        this._dpiSet := true
        try DllCall("user32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")   ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    }
}
