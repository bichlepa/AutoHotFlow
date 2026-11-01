#Requires AutoHotkey v2.0

; Shared settings of the mouse and keyboard elements of the package Default (WI-0126): the send mode with the mouse delay,
; and the coordinate mode of the mouse, as v1 sets them before a mouse call. These settings belong to this worker thread
; only (AutoHotkey keeps them per thread), so they are set directly and not through SystemOps (ELEMENT-API-V2 3.3a).
class MouseOps {
    ; SendMode for the call that follows (Input, Event or Play, the v1 choices). The mouse delay of v1 is set as well:
    ; Play takes the delay with its Play flag, the other modes without it (AutoHotkey ignores the delay of Input).
    static SetSendMode(mode, delay) {
        SendMode(mode)
        if (mode = "Play")
            SetMouseDelay(delay, "Play")
        else
            SetMouseDelay(delay)
    }

    ; CoordMode for the mouse: Screen, Window or Client as v1. "Relative" (move from the current mouse position) is the
    ; screen mode with the option R of the call (v1 wrote an empty mode and the option R).
    static SetCoordMode(mode) {
        CoordMode("Mouse", mode = "Relative" ? "Screen" : mode)
    }
}
