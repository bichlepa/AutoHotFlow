#Requires AutoHotkey v2.0
#Include ..\..\core\GuiLayout.ahk
#Include ..\..\core\Json.ahk
#Include ..\..\core\Lang.ahk
#Include ..\..\ui_common\UiFileDialogs.ahk

; The window of the flow settings (WI-0109, REQ-EDT-140, EditorFlowSettings): a Gui that shows the form of the controller and
; sends every change to it (Set). The window does not decide anything: the checks are the controller's (Check), OK and Cancel
; are its calls. After each call the window brings its controls in line with the controller's state (Sync), so an OK that
; the checks refuse shows the reason at once. Button "Show log" asks the controller (ShowLog).
;
; One window at a time; the window is not modal. Layout at 100 % (96 dpi) through GuiLayout, not scrolled: the dialog is
; short enough for a 768 pixel high screen.
class FlowSettingsWindow {
    static WIDTH := 480
    static MARGIN := 12
    static ROW := 8
    static LINE_H := 20
    static EDIT_H := 24
    static BUTTON_H := 30
    static BUTTON_W := 110
    static WARN_H := 40
    static LABEL_W := 220
    static BROWSE_W := 32

    __New(owner) {
        this.owner := owner          ; the hwnd of the editor window (the dialog belongs to it), 0 for none
        this.controller := ""        ; EditorFlowSettings
        this.gui := ""
        this.lay := ""
        this.open := false
        this.policyBox := ""         ; DropDown: the policies, the first is the global setting
        this.globalBox := ""         ; CheckBox: use the global working directory
        this.ownEd := ""             ; Edit: the own folder
        this.browseBtn := ""         ; Button: the folder dialog
        this.strictCb := ""          ; CheckBox: strict mode (checked) or compatible (unchecked)
        this.limitEds := Map()       ; limit key -> Edit
        this.notifyBox := ""         ; DropDown: default, on, off
        this.msgText := ""           ; Text: the warnings and the refusal of the checks
        this.showWindows := true     ; false: built but not shown (the unit test)
    }

    ; Shows the dialog of the controller; an old one is replaced.
    Show(controller) {
        this.Build(controller, "", true)
    }

    ; Hides the dialog (the controller closed its session).
    Hide() {
        this._Teardown()
    }

    ; Brings the controls in line with the controller's state.
    Sync() {
        if (!this.open || !IsObject(this.controller) || !this.controller.Busy)
            return
        st := this.controller.State()
        if (st["open"] != Json.True)
            return
        this._SetDropDown(this.policyBox, EditorFlowSettings.POLICIES, st["policy"])
        this.globalBox.Value := st["useGlobalDir"] == Json.True ? 1 : 0
        if (this.ownEd.Value != st["workingDir"])
            this.ownEd.Value := st["workingDir"]
        this.ownEd.Enabled := st["useGlobalDir"] == Json.True ? false : true
        this.browseBtn.Enabled := st["useGlobalDir"] == Json.True ? false : true
        this.strictCb.Value := st["strict"] == Json.True ? 1 : 0
        for key in EditorFlowSettings.LIMITS {
            ctl := this.limitEds[key]
            if (ctl.Value != st["limits"][key])
                ctl.Value := st["limits"][key]
        }
        this._SetDropDown(this.notifyBox, EditorFlowSettings.NOTIFY, st["notify"])
        texts := []
        for text in st["errors"]
            texts.Push(text)
        for text in st["warnings"]
            texts.Push(text)
        this.msgText.Text := FlowSettingsWindow._Join(texts)
    }

    ; Builds the dialog. pos: [x, y] or "" (centred). show false builds it without showing it (the unit test).
    Build(controller, pos, show := true) {
        this._Teardown()
        this.showWindows := show
        this.controller := controller
        m := FlowSettingsWindow.MARGIN
        width := FlowSettingsWindow.WIDTH
        cw := width - 2 * m
        g := Gui("-DPIScale" (this.owner ? " +Owner" this.owner : ""))
        g.Title := Lang("Flow_settings_title", controller.session["name"])
        g.OnEvent("Close", (*) => this._Cancel())
        g.OnEvent("Escape", (*) => this._Cancel())
        this.gui := g
        this.lay := GuiLayout.Create(g, width, 100)
        this.open := true
        y := m
        y := this._Row(Lang("Flow_settings_policy"), y, cw)
        this.policyBox := g.AddDDL("AltSubmit", this._PolicyItems())
        this._Put(this.policyBox, m, y, cw, FlowSettingsWindow.EDIT_H)
        this.policyBox.OnEvent("Change", (*) => this._Choose("policy", this.policyBox, EditorFlowSettings.POLICIES))
        y += FlowSettingsWindow.EDIT_H + FlowSettingsWindow.ROW

        this.globalBox := g.AddCheckbox("", Lang("Use global working dir"))
        this._Put(this.globalBox, m, y, cw, FlowSettingsWindow.LINE_H)
        this.globalBox.OnEvent("Click", (*) => this._SetUseGlobal())
        y += FlowSettingsWindow.LINE_H + FlowSettingsWindow.ROW
        y := this._Row(Lang("Working directory"), y, cw)
        ew := cw - FlowSettingsWindow.BROWSE_W - FlowSettingsWindow.ROW
        this.ownEd := g.AddEdit("", "")
        this._Put(this.ownEd, m, y, ew, FlowSettingsWindow.EDIT_H)
        this.ownEd.OnEvent("Change", (*) => this.controller.Set("workingDir", this.ownEd.Value))
        this.browseBtn := g.AddButton("", Lang("Settings_browse"))
        this._Put(this.browseBtn, m + ew + FlowSettingsWindow.ROW, y, FlowSettingsWindow.BROWSE_W, FlowSettingsWindow.EDIT_H)
        this.browseBtn.OnEvent("Click", (*) => this._Browse())
        y += FlowSettingsWindow.EDIT_H + FlowSettingsWindow.ROW

        y := this._Row(Lang("Flow_settings_type"), y, cw)
        this.strictCb := g.AddCheckbox("", Lang("Flow_settings_strict"))
        this._Put(this.strictCb, m, y, cw, FlowSettingsWindow.LINE_H)
        this.strictCb.OnEvent("Click", (*) => this.controller.Set("strict", this.strictCb.Value))
        y += FlowSettingsWindow.LINE_H + FlowSettingsWindow.ROW

        y := this._Row(Lang("Flow_settings_limits"), y, cw)
        for key in EditorFlowSettings.LIMITS {
            label := g.AddText("", Lang(EditorFlowSettings.LIMIT_LABEL[key]))
            this._Put(label, m, y, FlowSettingsWindow.LABEL_W, FlowSettingsWindow.EDIT_H)
            ed := g.AddEdit("", "")
            this._Put(ed, m + FlowSettingsWindow.LABEL_W + FlowSettingsWindow.ROW, y
                , cw - FlowSettingsWindow.LABEL_W - FlowSettingsWindow.ROW, FlowSettingsWindow.EDIT_H)
            this._OnLimit(key, ed)
            this.limitEds[key] := ed
            y += FlowSettingsWindow.EDIT_H + FlowSettingsWindow.ROW
        }
        hint := g.AddText("", Lang("Flow_settings_limit_hint"))
        this._Put(hint, m, y, cw, FlowSettingsWindow.LINE_H)
        y += FlowSettingsWindow.LINE_H + FlowSettingsWindow.ROW

        y := this._Row(Lang("Flow_settings_notify"), y, cw)
        this.notifyBox := g.AddDDL("AltSubmit", this._NotifyItems())
        this._Put(this.notifyBox, m, y, cw, FlowSettingsWindow.EDIT_H)
        this.notifyBox.OnEvent("Change", (*) => this._Choose("notify", this.notifyBox, EditorFlowSettings.NOTIFY))
        y += FlowSettingsWindow.EDIT_H + FlowSettingsWindow.ROW

        this.msgText := g.AddText("cRed", "")
        this._Put(this.msgText, m, y, cw, FlowSettingsWindow.WARN_H)
        y += FlowSettingsWindow.WARN_H + FlowSettingsWindow.ROW

        bw := FlowSettingsWindow.BUTTON_W
        bh := FlowSettingsWindow.BUTTON_H
        logBtn := g.AddButton("", Lang("Show log"))
        this._Put(logBtn, m, y, bw, bh)
        logBtn.OnEvent("Click", (*) => this.controller.ShowLog())
        ok := g.AddButton("Default", Lang("OK"))
        this._Put(ok, width - m - 2 * bw - m, y, bw, bh)
        ok.OnEvent("Click", (*) => this._Ok())
        cancel := g.AddButton("", Lang("Cancel"))
        this._Put(cancel, width - m - bw, y, bw, bh)
        cancel.OnEvent("Click", (*) => this._Cancel())
        y += bh + m
        this.lay["h"] := y

        this.Sync()
        if (!show)
            return
        if (IsObject(pos))
            GuiLayout.Show(this.lay, pos[1], pos[2])
        else
            GuiLayout.Show(this.lay)
    }

    ; --- events ------------------------------------------------------------------------------------------------------------

    _Choose(field, box, list) {
        index := box.Value
        if (index >= 1 && index <= list.Length)
            this.controller.Set(field, list[index])
    }

    ; A limit field: its own closure over key and ed (a loop variable would hold the last key, HOW-TO).
    _OnLimit(key, ed) {
        ed.OnEvent("Change", (*) => this.controller.Set("limit:" key, ed.Value))
    }

    _SetUseGlobal() {
        this.controller.Set("useGlobalDir", this.globalBox.Value ? 1 : 0)
    }

    _Browse() {
        current := this.ownEd.Value
        folder := UiFileDialogs.Dir(this.gui.Hwnd, current, 1, Lang("Flow_settings_dir_title"))
        if (folder != "")
            this.controller.Set("workingDir", folder)
    }

    _Ok() {
        this.controller.Ok()
        this.Sync()
    }

    _Cancel() {
        this.controller.Cancel()
    }

    ; --- helpers -----------------------------------------------------------------------------------------------------------

    ; The items of the policy drop-down: the global setting first (default), then the four policies.
    _PolicyItems() {
        items := []
        globalWord := this._Global("executionPolicy", "parallel")
        items.Push(Lang("Flow_settings_global", globalWord))
        for word in EditorFlowSettings.POLICIES {
            if (word != "default")
                items.Push(Lang(EditorFlowSettings.POLICY_LABEL[word]))
        }
        return items
    }

    _NotifyItems() {
        on := this._Global("notifyUnhandledErrors", "1")
        return [Lang("Flow_settings_global", (on = "1" || on = "true") ? Lang("Flow_settings_on") : Lang("Flow_settings_off"))
            , Lang("Flow_settings_on"), Lang("Flow_settings_off")]
    }

    _Global(key, fallback) {
        if (!(this.controller.globals is Map) || !this.controller.globals.Has(key))
            return fallback
        v := this.controller.globals[key]
        return IsObject(v) ? fallback : String(v)
    }

    ; Chooses the entry of a list (the first is the global setting) that is the word.
    _SetDropDown(box, list, word) {
        for index, item in list {
            if (item = word) {
                if (box.Value != index)
                    box.Choose(index)
                return
            }
        }
    }

    _Row(text, y, cw) {
        label := this.gui.AddText("", text)
        this._Put(label, FlowSettingsWindow.MARGIN, y, cw, FlowSettingsWindow.LINE_H)
        return y + FlowSettingsWindow.LINE_H + 2
    }

    _Put(ctl, x, y, w, h) {
        GuiLayout.Place(this.lay, ctl, x, y, w, h)
    }

    _Teardown() {
        this.open := false
        if (IsObject(this.lay)) {
            GuiLayout.Destroy(this.lay)
            this.lay := ""
        }
        if (IsObject(this.gui)) {
            this.gui.Destroy()
            this.gui := ""
        }
        this.limitEds := Map()
        this.policyBox := ""
        this.globalBox := ""
        this.ownEd := ""
        this.browseBtn := ""
        this.strictCb := ""
        this.notifyBox := ""
        this.msgText := ""
    }

    static _Join(texts) {
        out := ""
        for text in texts
            out .= (out = "" ? "" : "`n") text
        return out
    }
}
