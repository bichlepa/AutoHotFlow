#Requires AutoHotkey v2.0
#Include ..\core\Lang.ahk

; The text of the status bar of the editor (WI-0090, REQ-EDT-030, v1 ui_UpdateStatusbartext): offset, zoom and the number
; of elements, separated by "|" as in v1. The texts are in assets/language/basic (keys Status_offset, Status_zoom and
; "%1% elements"). Pure: the window and cmd.test.state use the same text.
class FlowStatus {
    static SEPARATOR := "   |   "

    ; view: EditorView; elementCount: the number of elements of the flow; selection: the selected IDs (a Map, WI-0098).
    ; The last part is the v1 text of the selection: the elements, or one selected element (its ID), or the count.
    static Text(view, elementCount, selection := "") {
        count := (selection is Map) ? selection.Count : 0
        if (count = 0)
            middle := Lang("%1% elements", elementCount)
        else if (count = 1) {
            for id in selection
                middle := Lang("1 selected element: %1%", id)
        } else
            middle := Lang("%1% selected elements", count)
        return Lang("Status_offset", Round(view.OffsetX), Round(view.OffsetY)) FlowStatus.SEPARATOR
            . Lang("Status_zoom", Round(view.Zoom, 2)) FlowStatus.SEPARATOR . middle
    }
}
