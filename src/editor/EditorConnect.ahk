#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ConnectionRules.ahk
#Include FlowGeometry.ahk
#Include FlowHit.ahk
#Include FlowHitTest.ahk
#Include EditorAdd.ahk

; Connections in the editor (WI-0100, REQ-EDT-070, PROTOCOL 4.11, v1 ui_MoveConnection): the buttons of a selected element and
; of a selected connection start a gesture; the end that follows the pointer is dropped on an element (its part decides the
; loop part, as v1), or on empty space, where a new element is made of a kind and a class in the same patch. The rules of a
; connection (ConnectionRules) are checked before a question is asked, and a refused connection is shown in the status bar.
;
; Gestures (the kind of self.gesture):
;   "new"       the plus of an element: a connection from it (fromPart: the head or the foot of a loop); its end follows the pointer
;   "moveTo"    the move button 2 of a connection: its end moves, the start stays
;   "moveFrom"  the move button 1 of a connection: its start moves, the end stays
;   "split"     the plus of a connection: the connection is split at the drop; the new connection goes from the drop to the old end
; The pointer (EditorPointer) decides when a gesture is started, dropped or cancelled; this class asks the questions through the
; seam picker (the window shows a dialog, the headless driver answers cmd.test.pick): Pick(titleKey, textKey, buttons, done),
; buttons Array of [id, labelKey], done(id) once, "" for a cancel. A new element asks its kind, a connection from a condition
; its type, and then its class (EditorAdd.Add). Cancel at any step makes no patch.
;
; The patch of a gesture is one undo step. The type of a connection from a condition is asked when it is not yes, no or
; exception (v1: the selector); from any other element a connection that is neither normal nor exception becomes normal
; without a question (v1). ChangeType is the double click and the edit button of a connection: the selector of its start.
class EditorConnect {
    __New(model, add) {
        this.model := model
        this.add := add             ; EditorAdd: the class list of a new element (the same patch as the connection)
        this.picker := ""           ; the seam (see above); the role gives the window or the headless driver
        this.gesture := ""          ; the gesture being drawn: a Map with kind and fromId/fromPart or conn, or ""
        this.busy := false          ; a question is open: nothing else starts
    }

    ; --- starting a gesture ----------------------------------------------------------------------------------------------

    ; The plus of an element (name "plus": the head of a loop, "plus2": its foot) starts a connection from it. False when
    ; nothing starts (no flow, a gesture or question is open, or the element is not there).
    BeginNew(elementId, name) {
        root := this._Root()
        if (!this._Free(root) || !root["allElements"].Has(elementId))
            return false
        part := (name = "plus2") ? 3 : 1
        fromPart := ConnectionRules.FromPart(ConnectionRules.KindOf(root, elementId), part)
        this.gesture := Map("kind", "new", "fromId", elementId, "fromPart", fromPart)
        return true
    }

    ; The plus of a connection splits it at the drop.
    BeginSplit(connId) => this._BeginConnection("split", connId)

    ; Move button 1 of a connection: its start moves.
    BeginMoveFrom(connId) => this._BeginConnection("moveFrom", connId)

    ; Move button 2 of a connection: its end moves.
    BeginMoveTo(connId) => this._BeginConnection("moveTo", connId)

    _BeginConnection(kind, connId) {
        root := this._Root()
        if (!this._Free(root) || !root["allConnections"].Has(connId))
            return false
        this.gesture := Map("kind", kind, "conn", connId)
        return true
    }

    ; The pointer moved to the flow point (fx, fy): the connection being drawn follows it.
    Follow(fx, fy) {
        g := this.gesture
        root := this._Root()
        if (!(g is Map) || !(root is Map))
            return
        if (g["kind"] = "new") {
            request := Map("fromId", g["fromId"], "fromPart", g["fromPart"], "type", "normal")
        } else if (!root["allConnections"].Has(g["conn"])) {
            return
        } else if (g["kind"] = "moveFrom") {
            c := root["allConnections"][g["conn"]]
            request := Map("toId", c.Get("to", ""), "toPart", c.Get("toPart", ""))
        } else {
            c := root["allConnections"][g["conn"]]
            request := Map("fromId", c.Get("from", ""), "fromPart", c.Get("fromPart", ""), "type", c.Get("ConnectionType", "normal"))
        }
        request["x"] := fx
        request["y"] := fy
        this.model.SetConnecting(request)
    }

    ; Esc or the right button: the gesture ends, nothing is sent.
    Cancel() {
        if (!(this.gesture is Map))
            return
        this.gesture := ""
        this.model.SetConnecting("")
    }

    ; The end is dropped at the flow point (fx, fy). On an element it ends there (the part of the drop decides a loop part);
    ; on empty space the kind and the class of a new element are asked first.
    Drop(fx, fy) {
        g := this.gesture
        if (!(g is Map))
            return
        this.gesture := ""
        this.model.SetConnecting("")
        this.busy := true
        hit := ""
        sc := this.model.CurrentScene()
        if (IsObject(sc))
            hit := FlowHitTest.ElementAt(sc, fx, fy)
        if (IsObject(hit))
            this._Resolve(g, hit.Id, hit.Index, "", 0, 0)
        else
            this._AskKind(g, fx, fy)
    }

    ; The type of a connection is asked again (the double click and the edit button of a connection). The selector offers the
    ; types of its start element. A refused type is shown in the status bar.
    ChangeType(connId) {
        root := this._Root()
        if (!this._Free(root) || !root["allConnections"].Has(connId))
            return false
        c := root["allConnections"][connId]
        kind := ConnectionRules.KindOf(root, c.Get("from", ""))
        current := c.Get("ConnectionType", "")
        this.busy := true
        this._Ask("Connection type", "Select connection type", ConnectionRules.Options(kind)
            , (id) => this._TypeOf(connId, current, id))
        return true
    }

    ; --- the questions ---------------------------------------------------------------------------------------------------

    _AskKind(g, fx, fy) {
        buttons := [["action", "Action"], ["condition", "Condition"], ["loop", "Loop"]]
        if (g["kind"] = "moveFrom")
            buttons.Push(["trigger", "Trigger"])     ; only a connection that starts at the new element may start at a trigger
        origin := FlowGeometry.CentredOrigin(fx, fy)
        this._Ask("Connect a new element", "Choose the kind of the new element", buttons
            , (id) => this._Kind(g, id, origin[1], origin[2]))
    }

    _Kind(g, kind, x, y) {
        if (kind = "")
            return this._End()
        this._Resolve(g, "", 0, kind, x, y)
    }

    _Ask(titleKey, textKey, buttons, done) {
        if (!IsObject(this.picker)) {
            done("")
            return
        }
        this.picker.Pick(titleKey, textKey, buttons, done)
    }

    _TypeOf(connId, current, id) {
        root := this._Root()
        if (id != "" && StrLower(String(current)) != id && (root is Map) && root["allConnections"].Has(connId)) {
            c := root["allConnections"][connId]
            spec := Map("from", c.Get("from", ""), "to", c.Get("to", ""), "type", id
                , "fromPart", c.Get("fromPart", ""), "toPart", c.Get("toPart", ""))
            key := ConnectionRules.Refusal(root, spec, connId)
            if (key != "")
                this.model.Notice(key)
            else
                this._Send(this.model.draft.Commit([Map("op", "connection.update", "id", connId
                    , "fields", Map("ConnectionType", id))], true), "")
        }
        this._End()
    }

    ; --- the steps of a drop ---------------------------------------------------------------------------------------------

    ; The connections of the gesture with the ends of the drop: target is the element ID ("" for a new element of newKind).
    _Resolve(g, targetId, part, newKind, x, y) {
        root := this._Root()
        if (!(root is Map))
            return this._End()
        kind := (targetId != "") ? ConnectionRules.KindOf(root, targetId) : newKind
        specs := this._Specs(g, root, targetId, part, kind)
        if (!(specs is Array))
            return this._End()
        this._Types(specs, 1, newKind, () => this._Ready(g, specs, targetId, newKind, x, y))
    }

    ; The connections the gesture makes or changes, as specs (see ConnectionRules). A spec with "conn" "" is a new connection;
    ; "#new" (ConnectionRules.NEW) stands for the new element; a type "" is still to be chosen.
    _Specs(g, root, targetId, part, kind) {
        target := (targetId != "") ? targetId : ConnectionRules.NEW
        toPart := ConnectionRules.ToPart(kind, part)
        if (g["kind"] = "new")
            return [Map("conn", "", "from", g["fromId"], "fromPart", g["fromPart"], "to", target, "toPart", toPart, "type", "")]
        if (!root["allConnections"].Has(g["conn"]))
            return ""
        c := root["allConnections"][g["conn"]]
        if (g["kind"] = "moveTo")
            return [Map("conn", g["conn"], "from", c.Get("from", ""), "fromPart", c.Get("fromPart", ""), "to", target
                , "toPart", toPart, "type", c.Get("ConnectionType", ""))]
        if (g["kind"] = "moveFrom")
            return [Map("conn", g["conn"], "from", target, "fromPart", ConnectionRules.FromPart(kind, part)
                , "to", c.Get("to", ""), "toPart", c.Get("toPart", ""), "type", c.Get("ConnectionType", ""))]
        ; split (v1: both ends defined): the old connection ends at the target, a new one starts there and goes on to the old end
        isLoop := (StrLower(kind) = "loop")
        return [
            Map("conn", g["conn"], "from", c.Get("from", ""), "fromPart", c.Get("fromPart", ""), "to", target
                , "toPart", isLoop ? "HEAD" : "", "type", c.Get("ConnectionType", "")),
            Map("conn", "", "from", target, "fromPart", isLoop ? "TAIL" : "", "to", c.Get("to", ""), "toPart", c.Get("toPart", "")
                , "type", "")
        ]
    }

    ; The types of the specs from index i on: a type that the start element allows stays; a condition asks its selector; any
    ; other element gets normal (v1). done() when all have one.
    _Types(specs, i, newKind, done) {
        if (i > specs.Length) {
            done()
            return
        }
        spec := specs[i]
        kind := (spec["from"] = ConnectionRules.NEW) ? newKind : ConnectionRules.KindOf(this._Root(), spec["from"])
        if (ConnectionRules.Valid(kind, spec["type"]))
            return this._Types(specs, i + 1, newKind, done)
        if (StrLower(kind) != "condition") {
            spec["type"] := ConnectionRules.Default(kind)
            return this._Types(specs, i + 1, newKind, done)
        }
        this._Ask("Connection type", "Select connection type", ConnectionRules.Options(kind)
            , (id) => this._TypeChosen(specs, i, newKind, done, id))
    }

    _TypeChosen(specs, i, newKind, done, id) {
        if (id = "")
            return this._End()
        specs[i]["type"] := id
        this._Types(specs, i + 1, newKind, done)
    }

    ; All types are known: the refusals are checked first (nothing is asked for a refused connection any more), then the patch
    ; goes out, or for a new element the class is asked and the patch goes out with it.
    _Ready(g, specs, targetId, newKind, x, y) {
        root := this._Root()
        if (!(root is Map))
            return this._End()
        for spec in specs {
            key := ConnectionRules.Refusal(root, spec, spec["conn"])
            if (key != "") {
                this.model.Notice(key)
                return this._End()
            }
        }
        if (targetId != "") {
            built := this._Ops(specs, "")
            return this._Send(this.model.draft.Commit(built["ops"], true), built["select"])
        }
        connect := (newId) => this._Ops(specs, newId)["ops"]
        done := (ok) => this._End()
        if (!this.add.Add(newKind, x, y, connect, done)) {
            this.model.Notice("The connection was not made")
            this._End()
        }
    }

    ; The operations of the specs: a new connection is connection.add, a changed one connection.update with its ends and type
    ; (a part that is "" is removed). newId is the ID of the new element (the placeholder ConnectionRules.NEW is replaced by it).
    ; select is the ID of the connection that the drop made or changed.
    _Ops(specs, newId) {
        ops := []
        selectId := ""
        for spec in specs {
            from := (spec["from"] = ConnectionRules.NEW) ? newId : spec["from"]
            to := (spec["to"] = ConnectionRules.NEW) ? newId : spec["to"]
            if (spec["conn"] = "") {
                id := this.model.draft.NextId("connection")
                c := Map("ID", id, "from", from, "to", to, "type", "Connection", "ConnectionType", spec["type"])
                if (spec["fromPart"] != "")
                    c["fromPart"] := spec["fromPart"]
                if (spec["toPart"] != "")
                    c["toPart"] := spec["toPart"]
                ops.Push(Map("op", "connection.add", "connection", c))
                selectId := id
            } else {
                fields := Map("from", from, "to", to, "ConnectionType", spec["type"]
                    , "fromPart", (spec["fromPart"] != "") ? spec["fromPart"] : Json.Null
                    , "toPart", (spec["toPart"] != "") ? spec["toPart"] : Json.Null)
                ops.Push(Map("op", "connection.update", "id", spec["conn"], "fields", fields))
                selectId := spec["conn"]
            }
        }
        return Map("ops", ops, "select", selectId)
    }

    ; The result of a commit: a refused patch shows a text, a made one selects the connection (selectId "" keeps the selection).
    _Send(res, selectId) {
        if (!res["ok"]) {
            this.model.Notice("The connection was not made")
        } else if (selectId != "") {
            this.model.draft.SetSelection([selectId], "one")
            this.model.SelectionChanged()
        }
        this._End()
        return res["ok"]
    }

    _End() {
        this.busy := false
        this.gesture := ""
    }

    _Free(root) => (root is Map) && !this.busy && !(this.gesture is Map)

    _Root() {
        root := this.model.draft.root
        return (root is Map) ? root : ""
    }
}
