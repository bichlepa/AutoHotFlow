#Requires AutoHotkey v2.0

; What lies under a point of the flow (WI-0084, FlowHitTest). Kind is "element" (Index: the part, 1 for an action,
; 1 to 4 for a loop) or "connection" (Index: the segment, 1 to 5) or "button" (Index: the name of the button, WI-0097:
; edit, trash, plus, plus2, move1, move2). Id is the element or connection ID of the flow.
class FlowHit {
    __New(kind, id, index) {
        this.Kind := kind
        this.Id := id
        this.Index := index
    }
}
