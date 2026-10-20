#Requires AutoHotkey v2.0
#Include ..\core\Lang.ahk

; The text of the status bar of the editor (WI-0090, REQ-EDT-030, v1 ui_UpdateStatusbartext): offset, zoom and the number
; of elements, separated by "|" as in v1. The texts are in assets/language/basic (keys Status_offset, Status_zoom and
; "%1% elements"). Pure: the window and cmd.test.state use the same text.
class FlowStatus {
    static SEPARATOR := "   |   "

    ; view: EditorView; elementCount: the number of elements of the flow.
    static Text(view, elementCount) {
        return Lang("Status_offset", Round(view.OffsetX), Round(view.OffsetY)) FlowStatus.SEPARATOR
            . Lang("Status_zoom", Round(view.Zoom, 2)) FlowStatus.SEPARATOR
            . Lang("%1% elements", elementCount)
    }
}
