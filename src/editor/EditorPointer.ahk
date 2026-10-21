#Requires AutoHotkey v2.0
#Include FlowRect.ahk
#Include FlowGeometry.ahk
#Include FlowHit.ahk
#Include FlowHitTest.ahk
#Include NewElementFields.ahk

; The mouse of the editor (WI-0098, REQ-EDT-060, REQ-EDT-030, PROTOCOL 4.11, E0094): what the buttons and the pointer do to
; the flow. The window (EditorWindow) and the headless driver (cmd.test.mouse) call the same three methods Down, Move and
; Up, so the tests reach the handlers of the window.
;
; Left button:
;   - a click on an element or a connection selects it alone; Ctrl toggles it; a click on an empty place unselects all
;     (Ctrl keeps the selection). A click on an element that is already selected selects it alone on release (v1).
;   - a drag from an empty place draws the selection rectangle (E0094). An element is selected when its box touches the
;     rectangle (not only when it lies inside), a connection when both its elements are selected. Ctrl adds to the
;     selection the rectangle picks.
;   - a drag from a selected element moves the whole selection; a drag from the tail of a loop (parts 3 and 4) that is
;     the only selected element changes the height of its bar, at least two grid steps (v1). A connection is not dragged.
;   - the drop snaps to the grid (FlowGeometry.Snap, v1) and sends one patch with one element.update per moved element (x, y,
;     or HeightOfVerticalBar): one undo step. A drop where nothing changed sends nothing.
; Right button: the view moves with the pointer (REQ-EDT-030, v1 ui_scrollwithMouse); it is no undo step.
; Esc, or the right button during a drag of the left one, cancels: no patch, no undo step, and the selection of a rectangle
; goes back to the one at the press. A drag runs while the button is held (the window holds the mouse with SetCapture while
; Holding is true); a lost button ends it as a cancel.
; Placing a new element (WI-0099, REQ-EDT-050): a left press on one of the four fields (NewElementFields) starts the mode
; "place": the box of the new element (Model.SetGhost) follows the pointer. A drag places it where the button goes up, a
; click leaves it following until the next left click places it. Esc or the right button cancels. A placed element goes to
; onPlace(kind, x, y) (the flow position of its top left corner); the class is asked there, not here.
;
; Connections (WI-0100, REQ-EDT-070): a left press on a button of the selection (plus, plus2, move1, move2, edit) starts a
; gesture of EditorConnect, and the mode "connect" begins: the connection follows the pointer, as the placing does. A drag
; drops it where the button goes up; a click leaves it following until the next left click drops it. Esc or the right
; button cancels. A double click on a connection (two clicks within DOUBLE_MS) asks its type (EditorConnect.ChangeType).
;
; Modes: "" (nothing), "press" (left button down, no drag yet, or a drag from a connection), "move", "tail", "rect", "view",
; "place" and "connect". The mode is the state of the pointer; the model gets the drag (SetDrag) or the rectangle (SetRect)
; while it runs.
class EditorPointer {
    static MOVE_PX := 3              ; the movement in canvas pixels that makes a drag (v1 detects 2 and more)
    static DOUBLE_MS := 500          ; two clicks on a connection within this time are a double click (its type is asked)

    __New(model) {
        this.model := model
        this.mode := ""
        this.cx := 0                 ; canvas pixel of the press, and of the last view step
        this.cy := 0
        this.pressFlow := [0, 0]     ; the flow point of the press
        this.ctrl := false
        this.moved := false          ; the pointer moved beyond MOVE_PX since the press
        this.itemId := ""            ; the element or connection under the press ("" for an empty place)
        this.itemKind := ""          ; "element", "connection", "empty" (the press)
        this.part := 0               ; the part of the element under the press (FlowHit index; 0 for none)
        this.rule := ""              ; what a release without a movement does: "", "empty", "single" or "toggle"
        this.baseSelection := Map()  ; the selection at the press (a rectangle goes back to it on cancel)
        this.moveIds := Map()        ; the elements of a move (ID -> true)
        this.tailId := ""
        this.tailHeight := 0         ; the height of the bar of the loop at the start of its tail drag
        this.tailNew := 0            ; the height of the last step of the tail drag (snapped)
        this.dx := 0                 ; the offset of the last step of a move, in flow units
        this.dy := 0
        this.placeKind := ""         ; the kind of the new element being placed ("action", ...; mode "place")
        this.placeHeld := false      ; the press on the field is still held (no click or release yet)
        this.placeMoved := false     ; the pointer moved while the field's button was held: a drag places at the release
        this.onPlace := ""           ; function (kind, x, y): a new element was placed at the flow position x, y
        this.connect := ""           ; EditorConnect: the gestures of the connections (the role gives it; WI-0100)
        this.connectHeld := false    ; the press on a connection button is still held
        this.connectMoved := false   ; the pointer moved while the button was held: a drag drops at the release
        this.lastClickId := ""       ; the connection of the last click (a double click asks its type)
        this.lastClickTick := 0
        this.transfer := ""          ; EditorTransfer: delete, cut, copy and paste (WI-0101; the role gives it)
    }

    ; "" or the mode ("press", "move", "tail", "rect", "view"). The getter has another name than the field: AHK names are
    ; case-insensitive, so a getter Mode would make this.mode a read-only property (WI-0098, HOW-TO).
    CurrentMode => this.mode

    ; True while the pointer holds the mouse (the window captures it).
    Holding => (this.mode != "")

    ; A button went down at the canvas pixel (cx, cy). button: "left" or "right". The right button during a drag of the
    ; left one cancels that drag and starts nothing else.
    Down(button, cx, cy, ctrl := false) {
        if (this.mode = "view")
            return
        if (this.mode = "place") {
            if (button = "left")
                this._Place(cx, cy)
            else if (button = "right")
                this.Cancel()
            return
        }
        if (this.mode = "connect") {
            if (button = "left")
                this._Drop(cx, cy)
            else if (button = "right")
                this.Cancel()
            return
        }
        if (this.mode != "") {
            if (button = "right")
                this.Cancel()
            return
        }
        if (button = "right") {
            this.mode := "view"
            this.cx := cx
            this.cy := cy
            return
        }
        if (button != "left")
            return
        kind := NewElementFields.At(this.model.view.Dpi, cx, cy)
        if (kind != "") {
            this._StartPlace(kind, cx, cy)
            return
        }
        this.ctrl := ctrl
        this.moved := false
        this.cx := cx
        this.cy := cy
        this.pressFlow := this.model.view.ToFlow(cx, cy)
        hit := this._HitAt(this.pressFlow)
        if (IsObject(hit) && hit.Kind = "button" && this._ButtonPress(hit, cx, cy))
            return
        this.mode := "press"
        this.rule := ""
        this.itemId := ""
        this.itemKind := "empty"
        this.part := 0
        this.baseSelection := this._SelectionCopy()
        if (!IsObject(hit)) {
            this.rule := "empty"
            return
        }
        sc := this.model.CurrentScene()
        this.itemId := hit.Id
        this.itemKind := EditorPointer._KindOf(sc, hit.Id)
        this.part := (hit.Kind = "element") ? hit.Index : 0
        if (!this.model.draft.selection.Has(hit.Id))
            this._Select([hit.Id], ctrl ? "toggle" : "one")     ; selected at the press: a drag moves it at once
        else
            this.rule := ctrl ? "toggle" : "single"
    }

    ; The pointer moved to the canvas pixel (cx, cy). held: the button that is down ("left", "right" or "" for none).
    Move(cx, cy, held := "") {
        if (this.mode = "place") {
            if (held = "left")
                this.placeMoved := true
            this.model.SetGhost(this._GhostAt(cx, cy))
            return
        }
        if (this.mode = "connect") {
            if (held = "left")
                this.connectMoved := true
            pt := this.model.view.ToFlow(cx, cy)
            this.connect.Follow(pt[1], pt[2])
            return
        }
        if (this.mode = "view") {
            if (held != "right") {
                this.mode := ""
                return
            }
            dx := cx - this.cx
            dy := cy - this.cy
            if (dx != 0 || dy != 0) {
                this.cx := cx
                this.cy := cy
                this.model.ChangeView(this.model.view.Moved(dx, dy))
            }
            return
        }
        if (this.mode = "")
            return
        if (held != "left") {          ; the button went up without us (capture lost): nothing is changed
            this.Cancel()
            return
        }
        if (this.mode = "press") {
            if (Abs(cx - this.cx) < EditorPointer.MOVE_PX && Abs(cy - this.cy) < EditorPointer.MOVE_PX)
                return
            this.moved := true
            this._StartDrag()
            if (this.mode = "press")
                return                 ; a connection: nothing to drag
        }
        this._Update(cx, cy)
    }

    ; The button went up at the canvas pixel (cx, cy). A release of the left button ends a click or a drag; a release of
    ; the right button ends the view drag.
    Up(button, cx, cy) {
        if (this.mode = "view") {
            if (button = "right")
                this.mode := ""
            return
        }
        if (this.mode = "place") {
            if (button = "left" && this.placeHeld) {
                this.placeHeld := false
                if (this.placeMoved)
                    this._Place(cx, cy)
            }
            return
        }
        if (this.mode = "connect") {
            if (button = "left" && this.connectHeld) {
                this.connectHeld := false
                if (this.connectMoved)
                    this._Drop(cx, cy)
            }
            return
        }
        if (button != "left" || this.mode = "")
            return
        if (this.mode = "press") {
            if (!this.moved)
                this._Click()
        } else if (this.mode = "move") {
            this._DropMove()
        } else if (this.mode = "tail") {
            this._DropTail()
        } else if (this.mode = "rect") {
            this.model.SetRect("")
        }
        this._End()
    }

    ; Cancels the drag or the view drag that runs (Esc, the right button, a lost button). Nothing is sent, no undo step.
    Cancel() {
        if (this.mode = "place") {
            this._EndPlace()
            return
        }
        if (this.mode = "connect") {
            this.connect.Cancel()
            this._EndConnect()
            return
        }
        if (this.mode = "move" || this.mode = "tail")
            this.model.SetDrag("")
        else if (this.mode = "rect") {
            this.model.SetRect("")
            this._Select(EditorPointer._KeysOf(this.baseSelection), "one")
        }
        this._End()
    }

    ; Esc: cancels a drag; otherwise unselects all (EditorKeys).
    Escape() {
        if (this.mode != "")
            this.Cancel()
        else
            this._Select([], "none")
    }

    ; Ctrl+A: selects every element and connection (EditorKeys). Not during a drag.
    SelectAll() {
        if (this.mode = "")
            this._Select([], "all")
    }

    ; Ctrl+C, Ctrl+X, Ctrl+V and Del (WI-0101, EditorKeys): the transfer of the selection (EditorTransfer). Nothing happens
    ; during a drag or a placing. at: the canvas pixel of the mouse for a paste ("" for the middle of the view).
    Copy() {
        if (this.mode = "" && IsObject(this.transfer))
            this.transfer.Copy()
    }

    Cut() {
        if (this.mode = "" && IsObject(this.transfer))
            this.transfer.Cut()
    }

    Paste(at := "") {
        if (this.mode = "" && IsObject(this.transfer))
            this.transfer.Paste(at)
    }

    Delete() {
        if (this.mode = "" && IsObject(this.transfer))
            this.transfer.Delete()
    }

    ; The loop height of a tail drag: the nearest grid step, at least two steps (v1 ui_FitGridx and the minimum of v1).
    static LoopHeight(h) => Max(FlowGeometry.GRID * 2, FlowGeometry.Snap(h))

    ; --- placing a new element (WI-0099) ---------------------------------------------------------------------------------

    _StartPlace(kind, cx, cy) {
        this.mode := "place"
        this.placeKind := kind
        this.placeHeld := true
        this.placeMoved := false
        this.model.SetGhost(this._GhostAt(cx, cy))
    }

    ; The element is placed with its centre at the pointer. The placing ends first, so the box is gone when onPlace asks for
    ; the class.
    _Place(cx, cy) {
        kind := this.placeKind
        pt := this.model.view.ToFlow(cx, cy)
        origin := FlowGeometry.CentredOrigin(pt[1], pt[2])
        this._EndPlace()
        if (IsObject(this.onPlace)) {
            onPlace := this.onPlace              ; not this.onPlace(...): that would pass this as the first argument (HOW-TO)
            onPlace(kind, origin[1], origin[2])
        }
    }

    _EndPlace() {
        this.mode := ""
        this.placeKind := ""
        this.placeHeld := false
        this.placeMoved := false
        this.model.SetGhost("")
    }

    ; The box (FlowRect, flow units) of the new element at the pointer.
    _GhostAt(cx, cy) {
        pt := this.model.view.ToFlow(cx, cy)
        origin := FlowGeometry.CentredOrigin(pt[1], pt[2])
        bar := (this.placeKind = "loop") ? FlowGeometry.NEW_LOOP_BAR : 0
        return FlowGeometry.Bounds(this.placeKind, origin[1], origin[2], bar)
    }

    ; --- connections (WI-0100) --------------------------------------------------------------------------------------------

    ; A press on a button of the selection starts its gesture: true when the button is handled (the press selects nothing).
    ; plus of an element and plus2 (the foot of a loop), plus, move1 and move2 of a connection, and edit of a connection
    ; (the type is asked at once). The trash button asks for the selection (WI-0101). The edit button of an element is not
    ; handled here (its settings dialog comes with S0007).
    _ButtonPress(hit, cx, cy) {
        sc := this.model.CurrentScene()
        kind := EditorPointer._KindOf(sc, hit.Id)
        name := hit.Index
        if (kind = "element" && (name = "plus" || name = "plus2")) {
            if (!this.connect.BeginNew(hit.Id, name))
                return false
        } else if (kind = "connection" && name = "edit") {
            this.connect.ChangeType(hit.Id)
            return true
        } else if (kind = "connection" && name = "plus") {
            if (!this.connect.BeginSplit(hit.Id))
                return false
        } else if (kind = "connection" && name = "move1") {
            if (!this.connect.BeginMoveFrom(hit.Id))
                return false
        } else if (kind = "connection" && name = "move2") {
            if (!this.connect.BeginMoveTo(hit.Id))
                return false
        } else if (name = "trash" && (kind = "element" || kind = "connection") && IsObject(this.transfer)) {
            this.transfer.Delete()          ; the trash button asks for the selection, as Del does (WI-0101)
            return true
        } else {
            return false
        }
        this.mode := "connect"
        this.connectHeld := true
        this.connectMoved := false
        pt := this.model.view.ToFlow(cx, cy)
        this.connect.Follow(pt[1], pt[2])
        return true
    }

    ; The end of a connection is dropped at the canvas pixel (the mode ends first, so the question of the drop is not held up
    ; by the pointer).
    _Drop(cx, cy) {
        pt := this.model.view.ToFlow(cx, cy)
        this._EndConnect()
        this.connect.Drop(pt[1], pt[2])
    }

    _EndConnect() {
        this.mode := ""
        this.connectHeld := false
        this.connectMoved := false
    }

    ; --- the drag ---------------------------------------------------------------------------------------------------------

    ; The movement passed MOVE_PX: a rectangle, a move or a tail drag, by what was pressed.
    _StartDrag() {
        if (this.itemKind = "empty") {
            this.mode := "rect"
            return
        }
        sc := this.model.CurrentScene()
        el := EditorPointer._ElementOf(sc, this.itemId)
        if (!IsObject(el))
            return                     ; a connection: nothing to drag (the mode stays "press")
        if (el.Kind = "loop" && this.part >= 3 && this.model.draft.selection.Count = 1) {
            this.mode := "tail"
            this.tailId := this.itemId
            this.tailHeight := el.HeightOfVerticalBar
            this.tailNew := el.HeightOfVerticalBar
            return
        }
        ids := Map()
        for id in this.model.draft.selection {
            if (IsObject(EditorPointer._ElementOf(sc, id)))
                ids[id] := true
        }
        this.moveIds := ids
        this.dx := 0
        this.dy := 0
        this.mode := "move"
    }

    ; One step of the drag: the drag of the model follows the pointer (not snapped; the drop snaps).
    _Update(cx, cy) {
        cur := this.model.view.ToFlow(cx, cy)
        if (this.mode = "move") {
            this.dx := cur[1] - this.pressFlow[1]
            this.dy := cur[2] - this.pressFlow[2]
            this.model.SetDrag(Map("ids", this.moveIds, "dx", this.dx, "dy", this.dy, "heights", Map()))
        } else if (this.mode = "tail") {
            this.tailNew := EditorPointer.LoopHeight(this.tailHeight + (cur[2] - this.pressFlow[2]))
            this.model.SetDrag(Map("ids", Map(this.tailId, true), "dx", 0, "dy", 0
                , "heights", Map(this.tailId, this.tailNew)))
        } else if (this.mode = "rect") {
            rect := FlowRect.Between(this.pressFlow[1], this.pressFlow[2], cur[1], cur[2])
            this.model.SetRect(rect)
            ids := this._Touching(rect)
            if (this.ctrl) {
                for id in EditorPointer._KeysOf(this.baseSelection)
                    ids.InsertAt(1, id)
            }
            this._Select(ids, "one")
        }
    }

    ; The drop of a move: each moved element snapped to the grid, one patch for all of them (one undo step).
    _DropMove() {
        this.model.SetDrag("")
        if (this.dx = 0 && this.dy = 0)
            return
        root := this.model.draft.root
        if (!(root is Map))
            return
        elements := root.Get("allElements", Map())
        ops := []
        for id in this.moveIds {
            if (!elements.Has(id))
                continue
            el := elements[id]
            x := el.Get("x", 0)
            y := el.Get("y", 0)
            nx := FlowGeometry.Snap(x + this.dx)
            ny := FlowGeometry.Snap(y + this.dy)
            if (nx != x || ny != y)
                ops.Push(Map("op", "element.update", "id", id, "fields", Map("x", nx, "y", ny)))
        }
        if (ops.Length > 0)
            this.model.draft.Commit(ops, true)
    }

    ; The drop of a tail: the new height of the bar, one patch (one undo step) when it changed.
    _DropTail() {
        this.model.SetDrag("")
        if (this.tailNew = this.tailHeight)
            return
        this.model.draft.Commit([Map("op", "element.update", "id", this.tailId
            , "fields", Map("HeightOfVerticalBar", this.tailNew))], true)
    }

    ; A click (no movement): the rule of the press. Ctrl on an empty place does nothing.
    _Click() {
        if (this.rule = "empty") {
            if (!this.ctrl)
                this._Select([], "none")
        } else if (this.rule = "single") {
            this._Select([this.itemId], "one")
        } else if (this.rule = "toggle") {
            this._Select([this.itemId], "toggle")
        }
        if (this.itemKind = "connection" && !this.ctrl)
            this._ConnectionClicked()
    }

    ; A second click on the same connection within DOUBLE_MS asks its type (WI-0100, v1 double click on a connection).
    _ConnectionClicked() {
        now := A_TickCount
        if (this.lastClickId = this.itemId && now - this.lastClickTick < EditorPointer.DOUBLE_MS) {
            this.lastClickId := ""
            this.connect.ChangeType(this.itemId)
        } else {
            this.lastClickId := this.itemId
            this.lastClickTick := now
        }
    }

    _End() {
        this.mode := ""
        this.moved := false
        this.itemId := ""
        this.itemKind := ""
        this.part := 0
        this.rule := ""
        this.moveIds := Map()
        this.tailId := ""
        this.baseSelection := Map()
    }

    ; The elements and connections a rectangle picks: an element whose box touches it, a connection whose two elements
    ; are both picked. The scene is the base one (a rectangle is drawn without a drag).
    _Touching(rect) {
        ids := []
        sc := this.model.CurrentScene()
        if (!IsObject(sc))
            return ids
        touched := Map()
        for element in sc.Elements {
            if (rect.Overlaps(element.Bounds)) {
                touched[element.Id] := true
                ids.Push(element.Id)
            }
        }
        for connection in sc.Connections {
            if (touched.Has(connection.From) && touched.Has(connection.To))
                ids.Push(connection.Id)
        }
        return ids
    }

    ; --- helpers ----------------------------------------------------------------------------------------------------------

    _Select(ids, mode) {
        this.model.draft.SetSelection(ids, mode)
        this.model.SelectionChanged()
    }

    _SelectionCopy() {
        copy := Map()
        for id in this.model.draft.selection
            copy[id] := true
        return copy
    }

    _HitAt(pt) {
        sc := this.model.CurrentScene()
        if (!IsObject(sc))
            return ""
        return FlowHitTest.At(sc, pt[1], pt[2])
    }

    static _KeysOf(map) {
        keys := []
        for key in map
            keys.Push(key)
        return keys
    }

    ; "element", "connection" or "" for an ID of the scene.
    static _KindOf(sc, id) {
        if (IsObject(EditorPointer._ElementOf(sc, id)))
            return "element"
        if (IsObject(sc)) {
            for connection in sc.Connections {
                if (connection.Id = id)
                    return "connection"
            }
        }
        return ""
    }

    static _ElementOf(sc, id) {
        if (!IsObject(sc))
            return ""
        for element in sc.Elements {
            if (element.Id = id)
                return element
        }
        return ""
    }
}
