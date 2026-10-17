#Requires AutoHotkey v2.0
#Include ..\core\GuiLayout.ahk
#Include ..\core\Log.ahk
#Include ..\core\Lang.ahk
#Include UiTexts.ahk

; Dialogs of the UI roles that never block (WI-0069, rule 3). A dialog opens and the call returns at once. Its answer
; goes once to the callback callback(ok, value): ok true with the value of the button, the chosen item or the text;
; ok false with "close" for the close box and Escape, or "" for Cancel. A second answer is ignored.
;
; One dialog of a kind (confirm, input, choose) per owner window is open at a time: a request for a second one returns
; false and opens nothing (the owner is then told, e.g. by the status of its window). Owner: the handle of the owner
; window, 0 for none.
;
; Titles and texts are Lang keys (the arguments args* fill %1%, %2%, ...), registered in UiTexts, so they follow a
; language change. Item labels, the default text and the check messages are data and are shown as given.
; The standard dialogs (MsgBox, FileSelect, DirSelect) are not used here (HOW-TO gui-and-hotkeys, WI-0069 spike).
class UiDialogs {
    static _open := Map()   ; "<owner>|<kind>" -> true while such a dialog is open
    static WIDTH := 380     ; at 100 % (96 dpi)
    static MARGIN := 12
    static BUTTON_W := 110
    static BUTTON_H := 30
    static EDIT_H := 24
    static LINE_H := 20
    static LIST_H := 200

    ; Confirm: buttons is an Array of [id, labelKey]. callback(true, id) for a button, callback(false, "close") otherwise.
    static Confirm(owner, titleKey, textKey, buttons, callback, args*) {
        if (buttons.Length = 0)
            throw ValueError("Confirm needs at least one button")
        st := UiDialogs._Begin(owner, "confirm", titleKey, callback)
        if (!IsObject(st))
            return false
        m := this.MARGIN
        textH := this._TextHeight(Lang(textKey, args*))
        width := this.WIDTH
        y := m + textH + m
        height := y + this.BUTTON_H + m
        g := st["gui"]
        lay := st["lay"] := GuiLayout.Create(g, width, height)
        text := g.AddText()
        GuiLayout.Place(lay, text, m, m, width - 2 * m, textH)
        UiTexts.Register(st["hwnd"], text, textKey, "Text", args*)
        x := width - m - (buttons.Length * this.BUTTON_W + (buttons.Length - 1) * m)
        for i, button in buttons {
            ctl := g.AddButton(i = 1 ? "Default" : "")
            GuiLayout.Place(lay, ctl, x, y, this.BUTTON_W, this.BUTTON_H)
            UiTexts.Register(st["hwnd"], ctl, button[2])
            ctl.OnEvent("Click", this._Pick(st, true, button[1]))
            x += this.BUTTON_W + m
        }
        this._OnCancel(st, "close")
        GuiLayout.Show(lay)
        return true
    }

    ; Input: a text field with the default text. check is a function (value) that returns "" when the value is accepted
    ; and the error text otherwise (an empty check accepts everything). The OK button runs the check; a refused value
    ; keeps the dialog open and shows the error text. callback(true, value) on OK, callback(false, "") on Cancel,
    ; callback(false, "close") on the close box or Escape.
    static Input(owner, titleKey, textKey, default, check, callback, args*) {
        st := UiDialogs._Begin(owner, "input", titleKey, callback)
        if (!IsObject(st))
            return false
        m := this.MARGIN
        textH := this._TextHeight(Lang(textKey, args*))
        width := this.WIDTH
        editY := m + textH + 4
        statusY := editY + this.EDIT_H + 4
        buttonY := statusY + 18 + m
        height := buttonY + this.BUTTON_H + m
        g := st["gui"]
        lay := st["lay"] := GuiLayout.Create(g, width, height)
        text := g.AddText()
        GuiLayout.Place(lay, text, m, m, width - 2 * m, textH)
        UiTexts.Register(st["hwnd"], text, textKey, "Text", args*)
        edit := g.AddEdit(, default)
        GuiLayout.Place(lay, edit, m, editY, width - 2 * m, this.EDIT_H)
        status := st["status"] := g.AddText()
        GuiLayout.Place(lay, status, m, statusY, width - 2 * m, 18)
        x := width - m - (2 * this.BUTTON_W + m)
        ok := g.AddButton("Default")
        GuiLayout.Place(lay, ok, x, buttonY, this.BUTTON_W, this.BUTTON_H)
        UiTexts.Register(st["hwnd"], ok, "OK")
        ok.OnEvent("Click", (*) => UiDialogs._Submit(st, edit.Value, check))
        cancel := g.AddButton()
        GuiLayout.Place(lay, cancel, x + this.BUTTON_W + m, buttonY, this.BUTTON_W, this.BUTTON_H)
        UiTexts.Register(st["hwnd"], cancel, "Cancel")
        cancel.OnEvent("Click", this._Pick(st, false, ""))
        this._OnCancel(st, "close")
        GuiLayout.Show(lay)
        return true
    }

    ; Choose: one item of a list (items: Array of [id, label], the labels are shown as given). OK with no selection does
    ; nothing; a double click chooses. callback(true, id) on OK, callback(false, "") on Cancel, callback(false, "close")
    ; on the close box or Escape.
    static Choose(owner, titleKey, textKey, items, callback, args*) {
        st := UiDialogs._Begin(owner, "choose", titleKey, callback)
        if (!IsObject(st))
            return false
        m := this.MARGIN
        textH := this._TextHeight(Lang(textKey, args*))
        width := this.WIDTH
        listY := m + textH + 4
        buttonY := listY + this.LIST_H + m
        height := buttonY + this.BUTTON_H + m
        ids := []
        labels := []
        for item in items {
            ids.Push(item[1])
            labels.Push(item[2])
        }
        g := st["gui"]
        lay := st["lay"] := GuiLayout.Create(g, width, height)
        text := g.AddText()
        GuiLayout.Place(lay, text, m, m, width - 2 * m, textH)
        UiTexts.Register(st["hwnd"], text, textKey, "Text", args*)
        list := g.AddListBox(, labels)
        GuiLayout.Place(lay, list, m, listY, width - 2 * m, this.LIST_H)
        x := width - m - (2 * this.BUTTON_W + m)
        ok := g.AddButton("Default")
        GuiLayout.Place(lay, ok, x, buttonY, this.BUTTON_W, this.BUTTON_H)
        UiTexts.Register(st["hwnd"], ok, "OK")
        ok.OnEvent("Click", (*) => UiDialogs._Choose(st, list.Value, ids))
        list.OnEvent("DoubleClick", (*) => UiDialogs._Choose(st, list.Value, ids))
        cancel := g.AddButton()
        GuiLayout.Place(lay, cancel, x + this.BUTTON_W + m, buttonY, this.BUTTON_W, this.BUTTON_H)
        UiTexts.Register(st["hwnd"], cancel, "Cancel")
        cancel.OnEvent("Click", this._Pick(st, false, ""))
        this._OnCancel(st, "close")
        GuiLayout.Show(lay)
        return true
    }

    ; The answer of a choose dialog: nothing selected (index 0) is no answer.
    static _Choose(st, index, ids) {
        if (index >= 1 && index <= ids.Length)
            UiDialogs.Answer(st, true, ids[index])
    }

    ; The answer of an input dialog: a refused value stays in the dialog with its error text.
    static _Submit(st, value, check) {
        err := UiDialogs.CheckInput(check, value)
        if (err != "") {
            st["status"].Text := err
            return
        }
        UiDialogs.Answer(st, true, value)
    }

    ; The check of an input value: "" when accepted, the error text otherwise. A check that throws refuses the value
    ; with the message of the error (the dialog must not end in the event).
    static CheckInput(check, value) {
        if (!IsObject(check))
            return ""
        try {
            res := check(value)
        } catch as e {
            return "Error: " e.Message
        }
        return (res = "") ? "" : String(res)
    }

    ; Sets the answer of a dialog. The first answer wins; it releases the kind of the owner, destroys the window and then
    ; calls the callback. An error in the callback is logged; it must not end the event that answered.
    static Answer(st, ok, value) {
        if (st["done"])
            return
        st["done"] := true
        if (st["hwnd"])
            UiTexts.Forget(st["hwnd"])
        if (st["lay"])
            GuiLayout.Destroy(st["lay"])
        if (IsObject(st["gui"]))
            st["gui"].Destroy()
        UiDialogs._Release(st["owner"], st["kind"])
        try {
            st["callback"](ok, value)
        } catch as e {
            Log.Write("a0", "ui", "dialog callback failed (" st["kind"] "): " e.Message)
        }
    }

    ; Claims the kind of the owner for a new dialog: false when one of that kind is open already.
    static _Claim(owner, kind) {
        key := owner "|" kind
        if (UiDialogs._open.Has(key))
            return false
        UiDialogs._open[key] := true
        return true
    }

    static _Release(owner, kind) {
        key := owner "|" kind
        if (UiDialogs._open.Has(key))
            UiDialogs._open.Delete(key)
    }

    ; True while a dialog of the kind is open for the owner (tests and the owner's status).
    static IsOpen(owner, kind) => UiDialogs._open.Has(owner "|" kind)

    static _Begin(owner, kind, titleKey, callback) {
        if (!UiDialogs._Claim(owner, kind))
            return ""
        GuiLayout.EnableDpi()   ; before the first Gui of the thread
        g := Gui("-DPIScale" (owner ? " +Owner" owner : ""))
        st := Map("gui", g, "hwnd", g.Hwnd, "lay", "", "status", "", "owner", owner, "kind", kind,
            "callback", callback, "done", false)
        UiTexts.Register(g.Hwnd, g, titleKey, "Title")
        return st
    }

    static _OnCancel(st, value) {
        st["gui"].OnEvent("Close", (*) => UiDialogs.Answer(st, false, value))
        st["gui"].OnEvent("Escape", (*) => UiDialogs.Answer(st, false, value))
    }

    static _Pick(st, ok, value) => (*) => UiDialogs.Answer(st, ok, value)

    ; Lines of text at 100 %: a text of n lines needs n rows.
    static _TextHeight(text) {
        lines := 1
        loop parse text, "`n"
            lines := A_Index
        return lines * this.LINE_H
    }
}
