#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\GuiLayout.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ManagerModel.ahk

; The list of notices of the manager (WI-0075, REQ-USE-030, PROTOCOL 4.8): a view of the ManagerModel's notices. It holds no
; logic of its own: the list is the model's list (the newest kept entries, the newest first), the texts are the Lang keys
; of the entries (the engine sends keys, not texts).
;
;   - Opening the list is done by the model (ManagerModel.OpenNotices): the marks of the flows go with it.
;   - The list is rebuilt when the model changes it (a notice came in). A list of 50 rows is cheap, and notices are rare.
;   - Closing the window (the close box, or Hide) only hides it; the model keeps the list.
;
; Column widths are pixels at 100 % (GuiLayout.Scale). They are not set again when the DPI changes (not checked).
class NoticeWindow {
    static WIDTH := 760
    static HEIGHT := 420

    __New(model, openEditor := "") {
        this.model := model
        this.openEditor := openEditor      ; fn(flowId): the editor of a flow (WI-0103, the button "Open editor")
        this.rowNotices := []              ; the entry of each row, as the rows are shown
        this.win := UiWindow("manager.notices", "Notices", NoticeWindow.WIDTH, NoticeWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        this.lv := g.AddListView("+Report -Multi +Grid", [Lang("Notice_time"), Lang("Notice_level"), Lang("Notice_flow")
            , Lang("Notice_text")])
        this.win.Place(this.lv, 12, 12, 736, 370)
        lay := this.win.lay
        this.lv.ModifyCol(1, GuiLayout.Scale(lay, 80))
        this.lv.ModifyCol(2, GuiLayout.Scale(lay, 80))
        this.lv.ModifyCol(3, GuiLayout.Scale(lay, 170))
        this.lv.ModifyCol(4, GuiLayout.Scale(lay, 380))
        this.status := g.AddText()
        this.win.Place(this.status, 12, 390, 540, 20)
        this.openBtn := g.AddButton(, Lang("Notice_open_editor"))
        this.win.Place(this.openBtn, 580, 386, 168, 26)
        this.openBtn.OnEvent("Click", (*) => this.OpenSelected())
    }

    ; The button "Open editor" (WI-0103): the editor of the selected notice, which must be an editor notice. Nothing else
    ; is done here: the model asks the supervisor (ManagerModel.OpenEditor, the same as the button "Edit").
    OpenSelected() {
        row := this.lv.GetNext(0)
        if (row = 0 || row > this.rowNotices.Length) {
            this.win.Text(this.status, "Notice_pick_editor")
            return
        }
        e := this.rowNotices[row]
        if (e["kind"] != "editor" || e["flowId"] = "") {
            this.win.Text(this.status, "Notice_not_editor")
            return
        }
        if (IsObject(this.openEditor))
            this.openEditor(e["flowId"])
    }

    Show() {
        this.win.Show()
        this.Refresh()
    }

    ; A change of the language (WI-0078, ManagerWindow.Refresh): the column titles and the rows get the new texts.
    Relabel() {
        this.lv.ModifyCol(1,, Lang("Notice_time"))
        this.lv.ModifyCol(2,, Lang("Notice_level"))
        this.lv.ModifyCol(3,, Lang("Notice_flow"))
        this.lv.ModifyCol(4,, Lang("Notice_text"))
        this.Refresh()
    }

    Hide() {
        this.win.Hide()
    }

    Close() {
        this.win.Close()
    }

    Visible => this.win.Visible

    ; Rebuilds the rows from the model's list, the newest first.
    Refresh() {
        this.lv.Delete()
        this.rowNotices := []
        notices := this.model.notices
        i := notices.Length
        while (i >= 1) {
            e := notices[i]
            this.lv.Add("", e["clock"], Lang("Notice_level_" e["level"]), this._FlowName(e["flowId"]), this._Text(e))
            this.rowNotices.Push(e)
            i -= 1
        }
        if (notices.Length = 0)
            this.win.Text(this.status, "Notice_none")
        else
            this.status.Text := ""
    }

    ; The text of an entry: its Lang key with the arguments, and the count of the notices that were held back.
    _Text(e) {
        args := e["args"]
        ; An editor notice carries the flow ID (the supervisor does not know names); the list shows the name (WI-0103).
        if (e["kind"] = "editor" && e["flowId"] != "")
            args := [this._FlowName(e["flowId"])]
        text := Lang(e["key"], args*)
        if (e["held"] > 0)
            text .= " " Lang("Notice_more", e["held"])
        return text
    }

    _FlowName(flowId) {
        if (flowId = "")
            return ""
        rec := this.model.Flow(flowId)
        return rec = "" ? flowId : rec["name"]
    }
}
