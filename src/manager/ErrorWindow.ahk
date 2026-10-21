#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\GuiLayout.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ManagerModel.ahk

; The window of an unhandled error (WI-0113, REQ-USE-080 part 2, PROTOCOL 4.7a, 4.8): the flow, the element, the time and the
; message of the error, and the variables of its branch as the engine copied them (scope, name, value). It is read only and
; blocks nothing: the list is a view, the values cannot be changed here (the debugger comes in phase 4). The window holds no
; state of the error: the model asks the engine (ManagerModel.OpenError) and sends the answer as the event "error"; a new
; unhandled error while the window is open replaces the content (the model follows). Closing or hiding the window tells the
; model to stop following.
class ErrorWindow {
    static WIDTH := 720
    static HEIGHT := 470

    __New(model) {
        this.model := model
        this.data := ""      ; the last "error" event of the model that the window shows
        this.win := UiWindow("manager.error", "Error_title", ErrorWindow.WIDTH, ErrorWindow.HEIGHT)
        this.win.hideOnClose := true
        this.win.onHide := () => this.model.CloseError()
        g := this.win.Gui
        this.head := g.AddText()
        this.win.Place(this.head, 12, 12, 696, 96)
        this.lv := g.AddListView("+Report -Multi +Grid", [Lang("Error_col_scope"), Lang("Error_col_name"), Lang("Error_col_value")])
        this.win.Place(this.lv, 12, 114, 696, 330)
        lay := this.win.lay
        this.lv.ModifyCol(1, GuiLayout.Scale(lay, 90))
        this.lv.ModifyCol(2, GuiLayout.Scale(lay, 200))
        this.lv.ModifyCol(3, GuiLayout.Scale(lay, 380))
        this.status := g.AddText()
        this.win.Place(this.status, 12, 448, 696, 20)
    }

    Show() {
        this.win.Show()
    }

    ; The model's answer for the window (event "error"): Map(n, ok, entry) or Map(n, ok, code, message).
    Update(data) {
        this.data := data
        this.Refresh()
    }

    ; A change of the language (ManagerWindow.Refresh): the column titles and the texts of the shown error.
    Relabel() {
        this.lv.ModifyCol(1,, Lang("Error_col_scope"))
        this.lv.ModifyCol(2,, Lang("Error_col_name"))
        this.lv.ModifyCol(3,, Lang("Error_col_value"))
        this.Refresh()
    }

    Refresh() {
        this.lv.Delete()
        d := this.data
        if (d = "") {
            this.head.Text := ""
            this.status.Text := ""
            return
        }
        if (!d["ok"]) {
            this.head.Text := ""
            this.status.Text := Lang("Error_gone", d.Get("message", "") != "" ? d["message"] : d.Get("code", ""))
            return
        }
        e := d["entry"]
        this.head.Text := Lang("Error_flow", e["flowName"]) "`n" Lang("Error_element", e["elementId"]) "`n"
            . Lang("Error_time", e["time"]) "`n" Lang("Error_message", e["message"])
        for v in e["vars"]
            this.lv.Add("", Lang("Error_scope_" v["scope"]), v["name"], v["value"])
        omitted := e.Get("omitted", 0)
        if (omitted > 0)
            this.status.Text := Lang("Error_omitted", omitted)
        else if (e["vars"].Length = 0)
            this.status.Text := Lang("Error_none")
        else
            this.status.Text := ""
    }

    Hide() {
        this.win.Hide()
    }

    Close() {
        this.model.CloseError()
        this.win.Close()
    }

    Visible => this.win.Visible
}
