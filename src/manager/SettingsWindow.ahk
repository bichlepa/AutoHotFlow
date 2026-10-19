#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include ..\core\Lang.ahk
#Include ..\core\LangTable.ahk
#Include ..\core\SettingsModel.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ..\ui_common\UiFileDialogs.ahk
#Include SettingsForm.ahk

; The settings dialog of the manager (WI-0078, REQ-SET-010, REQ-SET-020, REQ-SET-050, REQ-SET-070, REQ-LNG-020): the tabs
; General, Flow settings and Debugging (the v1 names). It shows the settings the engine has (ManagerModel.settings; the
; defaults for a key the engine has not sent). OK checks every value (SettingsForm.Collect); a refused value keeps the
; dialog open and names the value in the status line. A checked set goes to the engine (ManagerModel.SetSettings): the
; dialog closes when the engine has written and applied it, and shows the refusal otherwise. Cancel discards the values.
;
; The tab names and the drop-down lists hold translated texts that a window cannot set again in place, so a change of the
; language makes the dialog again (Relabel): the values the user typed are kept, and UiWindow remembers the position.
; Sizes are pixels at 100 % (GuiLayout scales them).
class SettingsWindow {
    static WIDTH := 680         ; at 100 %; the height is measured when the dialog is made
    static MARGIN := 12
    static TAB_TOP := 12
    static TAB_HEAD := 30       ; the rows start below the tab headers
    static LABEL_X := 24
    static LABEL_W := 250
    static CTL_X := 282
    static CTL_W := 250
    static NOTE_X := 544
    static NOTE_W := 124
    static ROW_MIN := 30
    static STATUS_LINES := 4    ; the refusal field shows this many lines and scrolls for more
    static BUTTON_W := 110
    static BUTTON_H := 30

    __New(model) {
        this.model := model
        this.ctl := Map()          ; key -> control
        this.lists := Map()        ; key -> the values of a drop-down list, in the order of its items
        this.codes := []           ; the language codes of the language list: "" (language of Windows) first
        this.opened := Map()       ; the values at open (OK sends the changed ones)
        this.done := false
        this._Build()
    }

    ; Shows the dialog with the settings of the engine.
    Show() {
        this.Fill(this.model.settings)
        this.opened := this.Read()     ; the values as they are shown: OK sends only what the user changed
        this.win.Show()
    }

    Visible => !this.done && this.win.Visible

    ; True while the window exists (the close box of UiWindow destroys it without setting done).
    _Alive() => !this.done && DllCall("user32\IsWindow", "ptr", this.win.Hwnd, "int") != 0

    ; Makes the window again with the texts of the current language, with the values the user has typed.
    Relabel() {
        if (this.done)
            return
        values := this.Read()      ; the raw values the user typed: not checked again here
        status := this.statusCtl.Text
        visible := this.win.Visible
        this.win.Close()           ; its texts are forgotten by UiWindow, its position is remembered
        this._Build()
        this.FillRaw(values)
        this.statusCtl.Text := status
        if (visible)
            this.win.Show()
    }

    ; Closes the dialog (Cancel, a saved set, the close box).
    Close() {
        if (this.done)
            return
        this.done := true
        this.win.Close()
    }

    ; The values of the controls: key -> the value of the field (a language code, the value of a list, 1 or 0, a text).
    Read() {
        out := Map()
        for field in SettingsForm.FIELDS {
            key := field["key"]
            ctl := this.ctl[key]
            switch field["kind"] {
                case "language":
                    out[key] := this._ItemValue(this.codes, ctl.Value)
                case "list":
                    out[key] := this._ItemValue(this.lists[key], ctl.Value)
                case "check":
                    out[key] := ctl.Value ? 1 : 0
                default:
                    out[key] := ctl.Value
            }
        }
        return out
    }

    ; Sets the controls from a Map of values. A value that the checks of SettingsModel refuse, or a key that is missing, shows
    ; its default (the engine's value is checked again here, so the dialog never shows a value the engine would refuse).
    Fill(values) {
        checked := Map()
        for field in SettingsForm.FIELDS
            checked[field["key"]] := this._Checked(field["key"], values)
        this._Show(checked)
    }

    ; Sets the controls from raw values, as they were read from them (a language change keeps an invalid typed value).
    FillRaw(values) {
        raw := Map()
        for field in SettingsForm.FIELDS {
            key := field["key"]
            raw[key] := values.Has(key) ? values[key] : SettingsModel.Default(key)
        }
        this._Show(raw)
    }

    _Show(values) {
        for field in SettingsForm.FIELDS {
            key := field["key"]
            value := values[key]
            ctl := this.ctl[key]
            switch field["kind"] {
                case "language":
                    if (value != "" && this._IndexOf(this.codes, value) = 1 && this.codes[1] != value)
                        this._AddLanguage(value)    ; a code the program does not list stays in the list
                    ctl.Choose(this._IndexOf(this.codes, value))
                case "list":
                    ctl.Choose(this._IndexOf(this.lists[key], value))
                case "check":
                    ctl.Value := value ? 1 : 0
                default:
                    ctl.Value := String(value)
            }
        }
    }

    ; The button OK: checks the values; a refusal stays in the dialog, a checked set goes to the engine.
    OnOk() {
        changed := Map()               ; the keys whose value differs from the value at open
        for key, value in this.Read() {
            if (!this.opened.Has(key) || String(this.opened[key]) != String(value))
                changed[key] := value
        }
        if (changed.Count = 0) {       ; nothing changed: nothing is sent
            this.Close()
            return
        }
        res := SettingsForm.Collect(changed)
        if (!res["ok"]) {
            text := SettingsForm.ErrorText(res["errors"], (key) => this._LabelOf(key))
            this.statusCtl.Text := Lang("Settings_refused") "`r`n" StrReplace(text, "`n", "`r`n")   ; the field is an Edit: CR LF
            return
        }
        this.statusCtl.Text := ""
        this.model.SetSettings(res["partial"], (answer) => this._Answered(answer))
    }

    ; The answer of the engine to the set: a saved set closes the dialog, a refusal is shown and the dialog stays open.
    _Answered(answer) {
        if (!this._Alive())            ; the close box may have closed the window while the engine answered
            return
        if (answer["ok"]) {
            this.Close()
            return
        }
        message := answer["message"] != "" ? answer["message"] : answer["code"]
        this.statusCtl.Text := Lang("Settings_not_saved", message)
    }

    ; The Browse button of the working directory: a folder dialog from a click (UiFileDialogs, E0076).
    OnBrowse() {
        edit := this.ctl["workingDir"]
        path := UiFileDialogs.Dir(this.win.Hwnd, edit.Value, 1, Lang("Working_directory"))
        if (path != "")
            edit.Value := path
    }

    ; Makes the window with its controls. The texts are registered with UiTexts through UiWindow.
    _Build() {
        this.ctl := Map()
        this.lists := Map()
        this.codes := [""]
        heights := this._Heights()
        M := SettingsWindow.MARGIN
        this.win := UiWindow("manager.settings", "Settings", SettingsWindow.WIDTH, this._Height(heights), false)
        this.win.hideOnClose := false
        this.done := false
        g := this.win.Gui
        tabNames := []
        for tab in SettingsForm.TABS
            tabNames.Push(Lang(tab["label"]))
        tabs := g.AddTab3("", tabNames)
        this.win.Place(tabs, M, SettingsWindow.TAB_TOP, SettingsWindow.WIDTH - 2 * M, heights["tabH"])
        for i, tab in SettingsForm.TABS {
            tabs.UseTab(i)
            y := SettingsWindow.TAB_TOP + SettingsWindow.TAB_HEAD
            row := 1
            for field in SettingsForm.FieldsOf(tab["id"]) {
                this._Row(g, field, y, heights[tab["id"]][row])
                y += heights[tab["id"]][row]
                row += 1
            }
        }
        tabs.UseTab()
        y := SettingsWindow.TAB_TOP + heights["tabH"] + M
        this.statusCtl := g.AddEdit("ReadOnly Multi VScroll")
        this.win.Place(this.statusCtl, M, y, SettingsWindow.WIDTH - 2 * M, heights["status"])
        y += heights["status"] + M
        ok := g.AddButton("Default")
        this.win.Place(ok, SettingsWindow.WIDTH - M - (2 * SettingsWindow.BUTTON_W + M), y, SettingsWindow.BUTTON_W, SettingsWindow.BUTTON_H)
        this.win.Text(ok, "OK")
        ok.OnEvent("Click", (*) => this.OnOk())
        cancel := g.AddButton()
        this.win.Place(cancel, SettingsWindow.WIDTH - M - SettingsWindow.BUTTON_W, y, SettingsWindow.BUTTON_W, SettingsWindow.BUTTON_H)
        this.win.Text(cancel, "Cancel")
        cancel.OnEvent("Click", (*) => this.Close())
        this.win.Gui.OnEvent("Escape", (*) => this.Close())
    }

    ; The heights at 100 % of everything that depends on the language: the rows of each tab (a label, a note or a checkbox
    ; text wraps at its column, GuiLayout.TextHeight), the tab control and the refusal field. Map: tab id -> Array of row
    ; heights, "tabH", "status". A probe window is made and destroyed here (the measure needs a window).
    _Heights() {
        GuiLayout.EnableDpi()
        probe := Gui("-DPIScale")
        out := Map()
        try {
            maxSum := 0
            for tab in SettingsForm.TABS {
                rows := []
                sum := 0
                for field in SettingsForm.FieldsOf(tab["id"]) {
                    h := SettingsWindow.ROW_MIN
                    if (field["kind"] != "check")
                        h := Max(h, GuiLayout.TextHeight(probe, Lang(field["label"]), SettingsWindow.LABEL_W) + 8)
                    if (field["note"] != "")
                        h := Max(h, GuiLayout.TextHeight(probe, Lang(field["note"]), SettingsWindow.NOTE_W) + 8)
                    rows.Push(h)
                    sum += h
                }
                out[tab["id"]] := rows
                maxSum := Max(maxSum, sum)
            }
            out["tabH"] := SettingsWindow.TAB_HEAD + maxSum + 12
            lines := ""
            loop SettingsWindow.STATUS_LINES
                lines .= (A_Index > 1 ? "`n" : "") "A"
            out["status"] := GuiLayout.TextHeight(probe, lines, SettingsWindow.WIDTH - 2 * SettingsWindow.MARGIN) + 8
        } finally {
            probe.Destroy()
        }
        return out
    }

    ; The height of the whole dialog at 100 %: the tabs, the refusal field, the buttons.
    _Height(heights) => SettingsWindow.TAB_TOP + heights["tabH"] + SettingsWindow.MARGIN + heights["status"]
        + SettingsWindow.MARGIN + SettingsWindow.BUTTON_H + SettingsWindow.MARGIN

    ; One row of a tab, at the height h of its text: the label, the control (the Browse button of a folder), the note.
    _Row(g, field, y, h) {
        key := field["key"]
        kind := field["kind"]
        if (kind != "check") {
            label := g.AddText("+0x80")
            this.win.Place(label, SettingsWindow.LABEL_X, y + 4, SettingsWindow.LABEL_W, h - 8)
            this.win.Text(label, field["label"])
        }
        switch kind {
            case "language":
                items := [Lang("Windows_language")]
                for entry in LangTable.Languages() {
                    this.codes.Push(entry[1])
                    items.Push(entry[2] " (" entry[1] ")")
                }
                list := g.AddDropDownList(, items)
                this.win.Place(list, SettingsWindow.CTL_X, y + 2, SettingsWindow.CTL_W)
                this.ctl[key] := list
            case "list":
                values := []
                items := []
                for item in field["items"] {
                    values.Push(item[1])
                    items.Push(Lang(item[2]))
                }
                this.lists[key] := values
                list := g.AddDropDownList(, items)
                this.win.Place(list, SettingsWindow.CTL_X, y + 2, SettingsWindow.CTL_W)
                this.ctl[key] := list
            case "check":
                ; the box and its own text in one control, as wide as the row: a narrow box clips the text
                check := g.AddCheckBox(, "")
                this.win.Place(check, SettingsWindow.LABEL_X, y + 4, SettingsWindow.LABEL_W + SettingsWindow.CTL_W + 100, h - 8)
                this.win.Text(check, field["label"])
                this.ctl[key] := check
            case "folder":
                edit := g.AddEdit("ReadOnly")
                this.win.Place(edit, SettingsWindow.CTL_X, y + 4, SettingsWindow.CTL_W - 80, 24)
                this.ctl[key] := edit
                browse := g.AddButton(, "")
                this.win.Place(browse, SettingsWindow.CTL_X + SettingsWindow.CTL_W - 70, y + 4, 70, 24)
                this.win.Text(browse, "Browse")
                browse.OnEvent("Click", (*) => this.OnBrowse())
            default:
                edit := g.AddEdit()
                this.win.Place(edit, SettingsWindow.CTL_X, y + 4, 100, 24)
                this.ctl[key] := edit
        }
        if (field["note"] != "") {
            note := g.AddText("+0x80")
            this.win.Place(note, SettingsWindow.NOTE_X, y + 4, SettingsWindow.NOTE_W, h - 8)
            this.win.Text(note, field["note"])
        }
    }

    ; A language code that the list of the program does not have is added to it, so that OK does not reset it.
    _AddLanguage(code) {
        this.codes.Push(code)
        this.ctl["language"].Add([code])
    }

    ; The value of a list item (1-based index of the drop-down list); a list without a selection gives "".
    _ItemValue(values, index) => (index >= 1 && index <= values.Length) ? values[index] : ""

    ; The index of a value in a list (1 when it is not there, so the first item is shown).
    _IndexOf(values, value) {
        for i, item in values {
            if (item = value)
                return i
        }
        return 1
    }

    ; The value of a key of the given values, checked by SettingsModel; the default when it is missing or refused.
    _Checked(key, values) {
        if (!values.Has(key))
            return SettingsModel.Default(key)
        try {
            return SettingsModel.Check(key, values[key])
        } catch as e {
            if (!(e is AhfError))
                throw e
            return SettingsModel.Default(key)
        }
    }

    ; The translated label of a key (the names in a refusal).
    _LabelOf(key) {
        field := SettingsForm.FieldOf(key)
        return field = "" ? key : Lang(field["label"])
    }
}
