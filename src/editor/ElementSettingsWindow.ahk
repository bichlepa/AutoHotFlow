#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Log.ahk
#Include ..\elements\base\ParamEvaluator.ahk
#Include ..\ui_common\UiDialogs.ahk
#Include ..\ui_common\UiFileDialogs.ahk
#Include form\FormChecks.ahk
#Include NewElementCatalog.ahk

; The settings window of an element (WI-0106, REQ-EDT-120, PROTOCOL 4.11): a Gui drawn from the form model (ElementForm, the
; headless model of WI-0105) that EditorSettings holds. The window shows the fields in order, in a scroll area; OK, Cancel
; and Help stay below it. A change of a field calls EditorSettings.SetValue (and so the checks of the element run again);
; the window then brings every control in line with the form (Sync). A change of the structure (the choices or the label of a
; field, the content types) builds the window again at its place.
;
; The window is not modal and does not block: it opens and returns at once, and the events call the controller. Layout at
; 100 % (96 dpi) through GuiLayout (DPI and the font). Content longer than the screen scrolls with the slider at the right
; edge and the mouse wheel. Help is disabled until the help window (WI-0111). A button of an element (for example the
; import of a window, WI-0110) is shown disabled until its assistant exists.
class ElementSettingsWindow {
    static WIDTH := 480
    static MARGIN := 12
    static ROW := 6
    static EDIT_H := 24
    static LINE_H := 20
    static WARN_H := 18
    static BUTTON_H := 30
    static BUTTON_W := 110
    static SLIDER_W := 18
    static LIST_H := 100
    static MULTI_H := 80
    static SCROLL_STEP := 40
    static KIND_KEY := Map("action", "Action", "condition", "Condition", "loop", "Loop", "trigger", "Trigger")
    static WEEKDAYS := ["Mon #Short for Monday", "Tue #Short for Tuesday", "Wed #Short for Wednesday"
        , "Thu #Short for Thursday", "Fri #Short for Friday", "Sat #Short for Saturday", "Sun #Short for Sunday"]
    static DATE_FORMAT := Map("time", "HH:mm:ss", "date", "yyyy-MM-dd", "datetime", "yyyy-MM-dd HH:mm:ss")

    __New(owner) {
        this.owner := owner          ; the hwnd of the editor window (the settings belong to it), 0 for none
        this.controller := ""        ; EditorSettings
        this.gui := ""
        this.lay := ""
        this.open := false
        this.entries := []           ; Array of Map: kind, field, id, ctls, ed, warn, mig, pic, sel, len
        this.content := []           ; Array of Map("it", layout item, "base", y at offset 0, "h", height, "ctl", control)
        this.nameEd := ""
        this.stdCb := ""
        this.nameWarn := ""
        this.slider := ""
        this.offset := 0
        this.viewH := 0
        this.maxOff := 0
        this.signature := ""
        this.showWindows := true     ; false: the windows are built but not shown (the unit test)
        this.wheelFn := (wParam, lParam, msg, hwnd) => this._OnWheel(wParam, hwnd)
    }

    ; Shows the settings of the controller (EditorSettings) in a new window; the old one, if any, is replaced.
    Show(controller) {
        this.Build(controller, "")
    }

    ; True when hwnd is the top-level window of the open settings (the editor window ignores the wheel over it, F-9000).
    Owns(hwnd) => this.open && IsObject(this.gui) && hwnd = this.gui.Hwnd

    ; Hides the window (the controller closed its session).
    Hide() {
        this._Teardown()
    }

    ; Builds the window again at its place (the language changed while it is open).
    Refresh() {
        if (this.open && IsObject(this.controller))
            this._Rebuild()
    }

    ; Brings the controls in line with the form of the controller (after every change of the form).
    Sync() {
        if (!this.open || !IsObject(this.controller) || !this.controller.Busy)
            return
        form := this.controller.Form
        if (!IsObject(form))
            return
        if (this._Signature(form) != this.signature) {
            this._Rebuild()
            return
        }
        this._SyncAll(form)
    }

    ; ---- building ------------------------------------------------------------------------------------------------------

    ; Builds the window of the controller. pos: [x, y] of the window or "" (centred). show false builds it without showing it
    ; (the headless unit test of the rows, tests/ahk/editor_settings_window.test.ahk).
    Build(controller, pos, show := true) {
        this._Teardown()
        this.showWindows := show
        this.controller := controller
        s := controller.session
        form := controller.Form
        m := ElementSettingsWindow.MARGIN
        width := ElementSettingsWindow.WIDTH
        cw := width - 2 * m - ElementSettingsWindow.SLIDER_W - ElementSettingsWindow.ROW
        g := Gui("-DPIScale" (this.owner ? " +Owner" this.owner : ""))
        g.Title := this._Title(s, form)
        g.OnEvent("Close", (*) => this._Cancel())
        g.OnEvent("Escape", (*) => this._Cancel())
        this.gui := g
        this.lay := GuiLayout.Create(g, width, 100)
        this.open := true
        OnMessage(0x020A, this.wheelFn)
        y := m
        if (s["unknown"]) {
            y := this._UnknownRows(s, y, cw)
        } else {
            if (ElementSettingsWindow._Experimental(s["cls"])) {
                text := Lang("This element is experimental!")
                h := this._TextHeight(text, cw)
                this._TextCtl(text, y, cw, "cRed", h)
                y += h + ElementSettingsWindow.ROW
            }
            y := this._TypeRow(s, y, cw)
            y := this._NameRows(form, y, cw)
            for index, field in form.fields
                y := this._FieldRows(form, field, y, cw)
        }
        contentH := y
        buttonsY := this._Layout(contentH, m)
        this._Buttons(buttonsY, width, m)
        if (!s["unknown"]) {
            this._SyncAll(form)
            this.signature := this._Signature(form)
        }
        this._Scroll(0)
        if (!show)
            return
        if (IsObject(pos))
            GuiLayout.Show(this.lay, pos[1], pos[2])
        else
            GuiLayout.Show(this.lay)
    }

    ; The scroll area (viewH) and the slider; the window height. Returns the y of the buttons.
    _Layout(contentH, m) {
        width := ElementSettingsWindow.WIDTH
        maxH := this._MaxHeight()
        buttonsH := ElementSettingsWindow.BUTTON_H + 2 * m
        this.viewH := Max(Min(contentH, maxH - buttonsH), 40)
        this.maxOff := Max(contentH - this.viewH, 0)
        if (this.maxOff > 0) {
            this.slider := this.gui.AddSlider("Vertical Range0-" this.maxOff " ToolTip", 0)
            GuiLayout.Place(this.lay, this.slider, width - m - ElementSettingsWindow.SLIDER_W, m
                , ElementSettingsWindow.SLIDER_W, this.viewH)
            this.slider.OnEvent("Change", (*) => this._Scroll(this.slider.Value))
        }
        buttonsY := this.viewH + m
        this.lay["h"] := buttonsY + ElementSettingsWindow.BUTTON_H + m
        return buttonsY
    }

    _Buttons(y, width, m) {
        g := this.gui
        bw := ElementSettingsWindow.BUTTON_W
        bh := ElementSettingsWindow.BUTTON_H
        help := g.AddButton("Disabled", Lang("Help #noun"))
        GuiLayout.Place(this.lay, help, m, y, bw, bh)
        ok := g.AddButton("Default", Lang("OK"))
        GuiLayout.Place(this.lay, ok, width - m - 2 * bw - m, y, bw, bh)
        ok.OnEvent("Click", (*) => this._Ok())
        cancel := g.AddButton(, Lang("Cancel"))
        GuiLayout.Place(this.lay, cancel, width - m - bw, y, bw, bh)
        cancel.OnEvent("Click", (*) => this._Cancel())
    }

    _UnknownRows(s, y, cw) {
        y := this._TextRow(Lang("Settings_unknown") "`n" s["placeholder"], y, cw)
        y := this._TextRow(Lang("Settings_parameters"), y, cw)
        for key, value in s["stored"] {
            y := this._TextRow(key ": " (IsObject(value) ? "" : String(value)), y, cw)
        }
        return y
    }

    ; The type button (v1: "<kind> type: <class>"): opens the class list of the kind; the choice changes the class (WI-0106).
    _TypeRow(s, y, cw) {
        kindText := Lang(ElementSettingsWindow.KIND_KEY.Get(s["kind"], "Action"))
        btn := this.gui.AddButton("", Lang("Settings_type", kindText, ElementRegistry.ClassOf(s["classId"])))
        this._Put(btn, ElementSettingsWindow.MARGIN, y, cw, ElementSettingsWindow.BUTTON_H)
        btn.OnEvent("Click", (*) => this._ChooseType())
        return y + ElementSettingsWindow.BUTTON_H + ElementSettingsWindow.ROW
    }

    ; The class list of the kind (the tree of the new element's list, at the user's level and the current class). A choice goes
    ; to EditorSettings.ChangeClass; Cancel changes nothing.
    _ChooseType() {
        s := this.controller.session
        level := IsObject(this.controller.adder) ? this.controller.adder.userLevel : "Programmer"
        groups := NewElementCatalog.Groups(s["kind"], level, s["classId"])
        UiDialogs.Tree(this.gui.Hwnd, "Settings_type_title", "Choose the class of the new element", groups
            , (ok, id) => this._TypeChosen(ok ? id : ""))
    }

    _TypeChosen(id) {
        if (id != "" && this.open)
            this.controller.ChangeClass(id)
    }

    _NameRows(form, y, cw) {
        g := this.gui
        y := this._TextRow(Lang("name (noun)"), y, cw)
        this.nameEd := g.AddEdit("", "")
        this._Put(this.nameEd, ElementSettingsWindow.MARGIN, y, cw, ElementSettingsWindow.EDIT_H)
        this.nameEd.OnEvent("Change", (*) => this.controller.SetName(this.nameEd.Value))
        y += ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
        this.stdCb := g.AddCheckbox("", Lang("Settings_standard_name"))
        this._Put(this.stdCb, ElementSettingsWindow.MARGIN, y, cw, ElementSettingsWindow.LINE_H)
        this.stdCb.OnEvent("Click", (*) => this.controller.SetStandardName(this.stdCb.Value))
        y += ElementSettingsWindow.LINE_H + ElementSettingsWindow.ROW
        this.nameWarn := this._TextCtl("", y, cw, "cRed")
        return y + ElementSettingsWindow.WARN_H + ElementSettingsWindow.ROW
    }

    ; One field of the form: its label, its control or controls, its warnings and the migration places of the field.
    _FieldRows(form, field, y, cw) {
        kind := field.kind
        id := field.ids.Length ? field.ids[1] : ""
        m := ElementSettingsWindow.MARGIN
        if (kind = "label")
            return this._TextRow(field.label, y, cw)
        if (!field.isKnown)
            kind := "readonly"                      ; an unknown type: its value is shown, read only
        e := Map("kind", kind, "field", field, "id", id, "ctls", [], "ed", "", "pic", "", "sel", "", "len", 14, "mig", "")
        if (kind != "checkbox" && kind != "button" && field.label != "")
            y := this._TextRow(field.label, y, cw)
        switch kind {
            case "edit", "readonly":
                y := this._EditRow(form, field, e, y, cw)
            case "multilineedit":
                e["ed"] := this.gui.AddEdit("Multi", "")
                this._Put(e["ed"], m, y, cw, ElementSettingsWindow.MULTI_H)
                e["ed"].OnEvent("Change", (*) => this._Set(id, e["ed"].Value))
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.MULTI_H + ElementSettingsWindow.ROW
            case "checkbox":
                e["ed"] := this.gui.AddCheckbox("", field.label)
                this._Put(e["ed"], m, y, cw, ElementSettingsWindow.LINE_H)
                e["ed"].OnEvent("Click", (*) => this._Set(id, e["ed"].Value))
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.LINE_H + ElementSettingsWindow.ROW
            case "radio":
                y := this._RadioRows(form, field, e, y, cw)
            case "slider":
                e["ed"] := this.gui.AddSlider("Range0-100", 0)
                this._Put(e["ed"], m, y, cw, ElementSettingsWindow.LINE_H + 8)
                e["ed"].OnEvent("Change", (*) => this._Set(id, e["ed"].Value))
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.LINE_H + 8 + ElementSettingsWindow.ROW
            case "dropdown":
                e["ed"] := this.gui.AddDropDownList("", field.choices)
                this._Put(e["ed"], m, y, cw)
                e["ed"].OnEvent("Change", (*) => this._ChoicePicked(id, e["ed"]))
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
            case "combobox":
                e["ed"] := this.gui.AddComboBox("", field.choices)
                this._Put(e["ed"], m, y, cw)
                e["ed"].OnEvent("Change", (*) => this._Set(id, e["ed"].Text))
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
            case "hotkey":
                e["ed"] := this.gui.AddHotkey("", "")
                this._Put(e["ed"], m, y, cw, ElementSettingsWindow.EDIT_H)
                e["ed"].OnEvent("Change", (*) => this._Set(id, e["ed"].Value))
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
            case "button":
                e["ed"] := this.gui.AddButton("Disabled", field.label)
                this._Put(e["ed"], m, y, cw, ElementSettingsWindow.EDIT_H)
                e["ctls"].Push(e["ed"])
                y += ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
            case "file", "folder":
                y := this._PathRow(field, e, y, cw)
            case "weekdays":
                y := this._WeekdayRow(field, e, y, cw)
            case "dateandtime":
                y := this._DateRow(field, e, y, cw)
            case "listbox":
                y := this._ListRow(form, field, e, y, cw)
        }
        e["warn"] := this._TextCtl("", y, cw, "cRed")
        y += ElementSettingsWindow.WARN_H + ElementSettingsWindow.ROW
        if (this._MigrationOf(id) != "") {
            e["mig"] := this._TextCtl("", y, cw, "cGray")
            y += ElementSettingsWindow.WARN_H + ElementSettingsWindow.ROW
        }
        this.entries.Push(e)
        return y
    }

    ; A text field with an edit (and its icon of the content type, the selector of the content ID).
    _EditRow(form, field, e, y, cw) {
        m := ElementSettingsWindow.MARGIN
        id := e["id"]
        x := m
        if (field.content.Length) {
            e["pic"] := this.gui.AddPicture("w16 h16", ElementSettingsWindow._Asset("content_string.ico"))
            this._Put(e["pic"], x, y + 4, 16, 16)
            x += 22
        }
        selW := (field.contentId != "" && field.content.Length > 1) ? 150 : 0
        edW := cw - (x - m) - (selW ? selW + ElementSettingsWindow.ROW : 0)
        readOnly := (e["kind"] = "readonly")
        e["ed"] := this.gui.AddEdit(readOnly ? "ReadOnly" : "", "")
        this._Put(e["ed"], x, y, edW, ElementSettingsWindow.EDIT_H)
        e["ctls"].Push(e["ed"])
        if (!readOnly)
            e["ed"].OnEvent("Change", (*) => this._Set(id, e["ed"].Value))
        if (selW) {
            e["sel"] := this.gui.AddDropDownList("", field.content)
            this._Put(e["sel"], x + edW + ElementSettingsWindow.ROW, y, selW)
            e["sel"].OnEvent("Change", (*) => this._ContentPicked(field, e["sel"]))
            e["ctls"].Push(e["sel"])
        }
        return y + ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
    }

    _RadioRows(form, field, e, y, cw) {
        values := form.ChoiceValues(e["id"])
        for index, choice in field.choices {
            ctl := this.gui.AddRadio(index = 1 ? "Group" : "", choice)
            this._Put(ctl, ElementSettingsWindow.MARGIN, y, cw, ElementSettingsWindow.LINE_H)
            this._RadioEvent(ctl, e["id"], values, index)
            e["ctls"].Push(ctl)
            y += ElementSettingsWindow.LINE_H + 2
        }
        return y + ElementSettingsWindow.ROW
    }

    _RadioEvent(ctl, id, values, index) {
        ctl.OnEvent("Click", (*) => this._RadioPicked(id, values, index, ctl))
    }

    _RadioPicked(id, values, index, ctl) {
        if (ctl.Value = 1 && index <= values.Length)
            this._Set(id, values[index])
    }

    _PathRow(field, e, y, cw) {
        m := ElementSettingsWindow.MARGIN
        btnW := 64
        edW := cw - btnW - ElementSettingsWindow.ROW
        e["ed"] := this.gui.AddEdit("", "")
        this._Put(e["ed"], m, y, edW, ElementSettingsWindow.EDIT_H)
        id := e["id"]
        e["ed"].OnEvent("Change", (*) => this._Set(id, e["ed"].Value))
        btn := this.gui.AddButton("", Lang("Settings_browse"))
        this._Put(btn, m + edW + ElementSettingsWindow.ROW, y, btnW, ElementSettingsWindow.EDIT_H)
        btn.OnEvent("Click", (*) => this._Browse(id, field.kind, e["ed"].Value))
        e["ctls"].Push(e["ed"])
        e["ctls"].Push(btn)
        return y + ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
    }

    _WeekdayRow(field, e, y, cw) {
        m := ElementSettingsWindow.MARGIN
        dayW := Floor(cw / 7)
        id := e["id"]
        days := []
        for index, key in ElementSettingsWindow.WEEKDAYS {
            ctl := this.gui.AddCheckbox("", Lang(key))
            this._Put(ctl, m + (index - 1) * dayW, y, dayW, ElementSettingsWindow.LINE_H)
            ctl.OnEvent("Click", (*) => this._DaysPicked(id, days))
            days.Push(ctl)
            e["ctls"].Push(ctl)
        }
        e["days"] := days
        return y + ElementSettingsWindow.LINE_H + ElementSettingsWindow.ROW
    }

    _DateRow(field, e, y, cw) {
        fmt := ElementSettingsWindow.DATE_FORMAT.Get(field.format, ElementSettingsWindow.DATE_FORMAT["datetime"])
        e["ed"] := this.gui.AddDateTime("", "")
        SendMessage(0x1032, 0, StrPtr(fmt), e["ed"])      ; DTM_SETFORMATW: the format of the control (the option takes no spaces)
        this._Put(e["ed"], ElementSettingsWindow.MARGIN, y, cw, ElementSettingsWindow.EDIT_H)
        id := e["id"]
        e["ed"].OnEvent("Change", (*) => this._Set(id, ElementSettingsWindow._DateOut(e["ed"].Value, e["len"])))
        e["ctls"].Push(e["ed"])
        return y + ElementSettingsWindow.EDIT_H + ElementSettingsWindow.ROW
    }

    _ListRow(form, field, e, y, cw) {
        opt := field.multi ? "Multi" : ""
        e["ed"] := this.gui.AddListBox(opt, field.choices)
        this._Put(e["ed"], ElementSettingsWindow.MARGIN, y, cw, ElementSettingsWindow.LIST_H)
        id := e["id"]
        e["ed"].OnEvent("Change", (*) => this._ListPicked(id, field, e["ed"]))      ; a list box has no Click event in v2
        e["ctls"].Push(e["ed"])
        return y + ElementSettingsWindow.LIST_H + ElementSettingsWindow.ROW
    }

    ; A text row (a label): returns the y below it.
    _TextRow(text, y, cw) {
        h := this._TextHeight(text, cw)
        this._TextCtl(text, y, cw, "", h)
        return y + h + ElementSettingsWindow.ROW
    }

    ; A text control at y; warning and migration lines have one line (cRed, cGray). Returns the control.
    _TextCtl(text, y, cw, color := "", h := "") {
        if (h = "")
            h := ElementSettingsWindow.WARN_H
        ctl := this.gui.AddText(color, text)
        this._Put(ctl, ElementSettingsWindow.MARGIN, y, cw, h)
        return ctl
    }

    _TextHeight(text, cw) {
        if (text = "")
            return ElementSettingsWindow.LINE_H
        return Max(GuiLayout.TextHeight(this.gui, text, cw), ElementSettingsWindow.LINE_H)
    }

    ; A control at a place of the scroll area (its y is the place at offset 0). Fixed controls stay where they are.
    _Put(ctl, x, y, w, h := "") {
        GuiLayout.Place(this.lay, ctl, x, y, w, h)
        it := this.lay["items"][this.lay["items"].Length]
        this.content.Push(Map("it", it, "base", y, "h", (h = "") ? ElementSettingsWindow.EDIT_H : h, "ctl", ctl))
        return ctl
    }

    _Title(s, form) {
        name := (IsObject(form)) ? form.name : s["classId"]
        kind := ElementSettingsWindow.KIND_KEY.Get(s["kind"], "")
        typeText := (kind = "") ? "" : Lang(kind)
        return Lang("Settings_title", typeText, name)
    }

    ; ---- values and events ----------------------------------------------------------------------------------------------

    _Set(id, value) {
        if (id = "")
            return
        this.controller.SetValue(id, value)
    }

    _ChoicePicked(id, ctl) {
        values := this.controller.Form.ChoiceValues(id)
        index := ctl.Value
        if (index >= 1 && index <= values.Length)
            this._Set(id, values[index])
    }

    _ContentPicked(field, ctl) {
        index := ctl.Value
        if (index >= 1 && index <= field.content.Length)
            this._Set(field.contentId, field.content[index])
    }

    _DaysPicked(id, days) {
        text := ""
        for index, ctl in days {
            if (ctl.Value)
                text .= (text = "" ? "" : ",") index
        }
        this._Set(id, text)
    }

    _ListPicked(id, field, ctl) {
        values := field.enum.Length ? field.enum : field.choices
        text := ""
        if (field.multi) {
            for index, choice in field.choices {
                if (SendMessage(0x0187, index - 1, 0, ctl))      ; LB_GETSEL
                    text .= (text = "" ? "" : ",") values[index]
            }
        } else if (ctl.Value >= 1 && ctl.Value <= values.Length) {
            text := values[ctl.Value]
        }
        this._Set(id, text)
    }

    _Browse(id, kind, current) {
        root := ""
        if (current != "" && !InStr(current, "%"))
            SplitPath(current, , &root)
        owner := this.gui ? this.gui.Hwnd : 0
        if (kind = "folder") {
            path := UiFileDialogs.Dir(owner, root, 1, Lang("Settings_folder_title"))
        } else {
            path := UiFileDialogs.File(owner, "", root, Lang("Settings_file_title"))
        }
        if (path != "")
            this._Set(id, path)
    }

    _Ok() {
        this.controller.Ok()
    }

    _Cancel() {
        this.controller.Cancel()
    }

    ; ---- bringing the controls in line with the form ----------------------------------------------------------------------

    _SyncAll(form) {
        if (IsObject(this.nameEd)) {
            text := form.name
            if (this.nameEd.Value != text)
                this.nameEd.Value := text
            this.nameEd.Enabled := form.standardName ? false : true
            this.stdCb.Value := form.standardName ? 1 : 0
            this.nameWarn.Text := ElementSettingsWindow._Texts(this._FormWarnings(form))
        }
        for e in this.entries
            this._SyncEntry(form, e)
        this._Scroll(this.offset)
    }

    _SyncEntry(form, e) {
        field := e["field"]
        id := e["id"]
        for ctl in e["ctls"]
            ctl.Enabled := field.isEnabled ? true : false
        if (e["warn"] is Object)
            e["warn"].Text := ElementSettingsWindow._Texts(field.warnings)
        if (e["mig"] is Object)
            e["mig"].Text := this._MigrationOf(id)
        val := (id != "") ? form.GetValue(id) : ""
        text := IsObject(val) ? "" : String(val)
        switch e["kind"] {
            case "edit", "multilineedit", "readonly":
                ed := e["ed"]
                if (ed.Value != text)
                    ed.Value := text
                if (IsObject(e["sel"]))
                    this._SyncContent(form, field, e)
            case "file", "folder":
                ed := e["ed"]
                if (ed.Value != text)
                    ed.Value := text
            case "checkbox":
                e["ed"].Value := ParamEvaluator.Truthy(val) ? 1 : 0
            case "radio":
                idx := ElementSettingsWindow._IndexOf(form.ChoiceValues(id), val)
                for index, ctl in e["ctls"]
                    ctl.Value := (index = idx) ? 1 : 0
            case "slider":
                n := IsNumber(val) ? Round(val) : 0
                e["ed"].Value := Max(0, Min(100, n))
            case "dropdown":
                e["ed"].Value := ElementSettingsWindow._IndexOf(form.ChoiceValues(id), val)
            case "combobox":
                if (e["ed"].Text != text)
                    e["ed"].Text := text
            case "hotkey":
                if (e["ed"].Value != text)
                    e["ed"].Value := text
            case "weekdays":
                chosen := ElementSettingsWindow._Split(text)
                for index, ctl in e["days"]
                    ctl.Value := ElementSettingsWindow._Has(chosen, index) ? 1 : 0
            case "dateandtime":
                digits := RegExReplace(text, "\D", "")
                fmt := field.format
                e["len"] := (fmt = "time") ? 6 : (fmt = "date") ? 8 : (StrLen(digits) = 8 ? 8 : 14)
                e["ed"].Value := ElementSettingsWindow._DateIn(text, e["len"])
            case "listbox":
                ElementSettingsWindow._SyncList(field, e["ed"], text)
        }
    }

    ; The content type of an edit field: the icon and the selector.
    _SyncContent(form, field, e) {
        ct := FormChecks.ContentType(field, form.values)
        idx := 0
        for index, choice in field.content {
            if (StrLower(choice) = ct)
                idx := index
        }
        if (idx && e["sel"].Value != idx)
            e["sel"].Value := idx
        if (IsObject(e["pic"]))
            e["pic"].Value := ElementSettingsWindow._Asset(ElementSettingsWindow._IconName(ct))
    }

    ; The signature of the structure: what changes the rows (kinds, labels, choices, content types). A change of it builds the
    ; window again.
    _Signature(form) {
        sig := this.controller.session["classId"] "|"      ; a new class changes the type text and the fields
        for field in form.fields {
            sig .= field.kind "|" field.label "|" field.contentId "|" field.format "|"
            for c in field.choices
                sig .= c ","
            sig .= "|"
            for c in field.content
                sig .= c ","
            if (field.ids.Length) {
                sig .= "|"
                for v in form.ChoiceValues(field.ids[1])
                    sig .= v ","
            }
            sig .= ";"
        }
        return sig
    }

    _Rebuild() {
        pos := ""
        if (this.open) {
            try {
                this.gui.GetPos(&x, &y)
                pos := [x, y]
            }
        }
        this.Build(this.controller, pos, this.showWindows)
    }

    _FormWarnings(form) {
        out := []
        for warning in form.Warnings() {
            if (warning["id"] = "")
                out.Push(warning["text"])
        }
        return out
    }

    _MigrationOf(id) {
        if (id = "" || !IsObject(this.controller))
            return ""
        texts := []
        for entry in this.controller.Migration() {
            if (StrLower(entry["par"]) = StrLower(id)) {
                ids := ElementSettingsWindow._Texts(entry["ids"], ", ")
                texts.Push(Lang("Settings_migration", ids, entry["v1"]))
            }
        }
        return ElementSettingsWindow._Texts(texts, "`n")
    }

    ; ---- scrolling ----------------------------------------------------------------------------------------------------------

    ; Moves the rows to the offset and shows those that lie completely in the scroll area.
    _Scroll(off) {
        off := Max(0, Min(off, this.maxOff))
        this.offset := off
        for c in this.content {
            it := c["it"]
            top := c["base"] - off
            it[3] := top
            c["ctl"].Visible := (top >= 0 && top + c["h"] <= this.viewH) ? true : false
        }
        if (IsObject(this.slider) && this.slider.Value != off)
            this.slider.Value := off
        if (IsObject(this.lay))
            GuiLayout.Apply(this.lay)
    }

    _OnWheel(wParam, hwnd) {
        if (!this.open || !IsObject(this.gui) || hwnd != this.gui.Hwnd)
            return
        delta := (wParam >> 16) & 0xFFFF
        if (delta >= 0x8000)
            delta -= 0x10000
        this._Scroll(this.offset - (delta // 120) * ElementSettingsWindow.SCROLL_STEP)
    }

    _Teardown() {
        if (this.open)
            OnMessage(0x020A, this.wheelFn, 0)
        this.open := false
        if (IsObject(this.lay)) {
            GuiLayout.Destroy(this.lay)
            this.lay := ""
        }
        if (IsObject(this.gui)) {
            this.gui.Destroy()
            this.gui := ""
        }
        this.entries := []
        this.content := []
        this.nameEd := ""
        this.stdCb := ""
        this.nameWarn := ""
        this.slider := ""
        this.signature := ""
    }

    ; The height of the work area at 100 % (the window is at the DPI of the editor's window).
    _MaxHeight() {
        dpi := (this.owner && DllCall("user32\IsWindow", "ptr", this.owner)) ? DllCall("user32\GetDpiForWindow", "ptr", this.owner, "uint") : 96
        dpi := dpi > 0 ? dpi : 96
        MonitorGetWorkArea(MonitorGetPrimary(), , &top, , &bottom)
        return Round((bottom - top) * 96 / dpi)
    }

    ; ---- helpers ------------------------------------------------------------------------------------------------------------

    static _Asset(name) => RegExReplace(A_LineFile, "\\src\\editor\\[^\\]+$") "\assets\icons\" name

    ; True for a class whose Stability is Experimental (REQ-USE-020); a class without the property is not experimental.
    static _Experimental(cls) {
        if (!IsObject(cls))
            return false
        try {
            return cls.Stability = "Experimental"
        }
        return false
    }

    static _IconName(ct) {
        switch ct {
            case "variablename": return "content_variablename.ico"
            case "string", "rawstring": return "content_string.ico"
        }
        return "content_expression.ico"
    }

    ; The texts of a list joined (a text is kept as it is).
    static _Texts(list, sep := "; ") {
        if (!(list is Array))
            return list
        out := ""
        for item in list
            out .= (out = "" ? "" : sep) item
        return out
    }

    static _IndexOf(values, val) {
        text := IsObject(val) ? "" : String(val)
        for index, v in values {
            if (String(v) = text)
                return index
        }
        return 0
    }

    static _Split(text) {
        out := []
        for part in StrSplit(text, ",")
            out.Push(Trim(part))
        return out
    }

    static _Has(list, index) {
        for item in list {
            if (item = String(index))
                return true
        }
        return false
    }

    ; The text of a date control for a stored value: 14 digits (YYYYMMDDHH24MISS), the date and the time as the stored value has them.
    static _DateIn(text, len) {
        digits := RegExReplace(String(text), "\D", "")
        if (len = 6)
            return "20000101" SubStr(digits "000000", 1, 6)
        return SubStr(digits "00000000000000", 1, 14)
    }

    static _DateOut(value, len) {
        if (len = 6)
            return SubStr(value, 9, 6)
        if (len = 8)
            return SubStr(value, 1, 8)
        return value
    }

    ; The list selection (multi: LB_SETSEL for each item, single: the item that the value names).
    static _SyncList(field, ctl, text) {
        values := field.enum.Length ? field.enum : field.choices
        chosen := ElementSettingsWindow._Split(text)
        if (field.multi) {
            SendMessage(0x0185, 0, -1, ctl)                          ; LB_SETSEL: all off
            for index, value in values {
                if (ElementSettingsWindow._Has(chosen, value))
                    SendMessage(0x0185, 1, index - 1, ctl)           ; LB_SETSEL: this one on
            }
            return
        }
        index := ElementSettingsWindow._IndexOf(values, text)
        ctl.Value := index
    }
}
