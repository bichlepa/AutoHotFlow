#Requires AutoHotkey v2.0
#Include ..\ui_common\UiWindow.ahk

; The report of the import from v1 (WI-0076, REQ-MIG-040, REQ-MIG-060): a read-only text field, so the user can select and copy
; the text. The text is made by ManagerImport.Text and given to Show; the window holds no state of its own. Closing it only hides it.
class ImportReportWindow {
    static WIDTH := 640
    static HEIGHT := 460

    __New() {
        this.win := UiWindow("manager.importReport", "Import_report_title", ImportReportWindow.WIDTH, ImportReportWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        this.edit := g.AddEdit("ReadOnly Multi VScroll")
        this.win.Place(this.edit, 12, 12, 616, 436)
    }

    ; Shows the report text (lines separated by CRLF).
    Show(text) {
        this.edit.Value := text
        this.win.Show()
    }

    Hide() {
        this.win.Hide()
    }

    Close() {
        this.win.Close()
    }

    Visible => this.win.Visible
}
