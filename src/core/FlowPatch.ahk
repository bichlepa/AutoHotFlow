#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Json.ahk

; Patch operations of a flow (WI-0093, PROTOCOL 4.2, ARCHITECTURE 4.2): the one implementation that the engine applies
; and that the editor uses for its draft and its undo. It works on the parsed v1 flow (a Map with allElements,
; allConnections, flowSettings, ElementIDCounter, see engine/core/FlowDefinition.ahk) and knows nothing of the engine,
; the GUI or the processes.
;
; Apply(raw, ops) returns a NEW root Map. Everything the operations do not change is shared with the input: the
; revisions of a flow share their maps, so nothing reachable from raw may be changed here. The operations are applied
; in order and checked at the end as a whole (a connection that is changed twice, or a connection that is valid only
; after a later operation, is judged by the final state). A refused list throws AhfError (bad_payload) and returns
; nothing, so the caller changes nothing.
;
; Inverse(raw, ops) returns the operations that undo them: Diff of the result back to raw. ElementIDCounter is not
; undone (it only grows: an ID that was used is not given out again).
;
; Rules (PROTOCOL 4.2): element and connection IDs are "element" or "connection" and ten digits (v1 format); IDs are
; unique; the type of an element is a known kind (trigger, action, condition, loop, any case); a connection has known
; ends, a known ConnectionType (normal, yes, no, exception; any case), no connection into a trigger, none from an
; element to itself and no second identical connection; removing an element removes its connections; removing the
; default manual trigger makes the first remaining manual trigger the default (as v1, Element_checkAndFixDefaultTrigger);
; setting DefaultTrigger on a manual trigger clears it on the others.
; A JSON null in a field of an update deletes the key (a parameter in pars: the parameter).
class FlowPatch {
    static ELEMENT_ID_RE := "^element\d{10}$"
    static CONNECTION_ID_RE := "^connection\d{10}$"
    static KINDS := Map("trigger", 1, "action", 1, "condition", 1, "loop", 1)
    static CONNECTION_TYPES := Map("normal", 1, "yes", 1, "no", 1, "exception", 1)
    static OPS := Map("element.add", 1, "element.update", 1, "element.remove", 1, "connection.add", 1
        , "connection.update", 1, "connection.remove", 1, "flow.settings", 1)
    static DEFAULT_KEY := "DefaultTrigger"
    static MIGRATION_KEY := "migration"
    static COUNTER_KEY := "ElementIDCounter"
    static SETTINGS_KEY := "flowSettings"

    ; The new root of the flow after the operations. Throws AhfError when an operation is refused.
    static Apply(raw, ops) {
        if (!(raw is Map) || !(ops is Array))
            throw AhfError("a flow patch needs a flow object and an array of operations", ErrCode.BAD_PAYLOAD)
        w := Map("root", raw.Clone(), "owned", Map(), "touchedEls", Map(), "touchedCons", Map())
        loop ops.Length
            FlowPatch._Run(w, A_Index, ops[A_Index])
        FlowPatch._CheckTouched(w)
        return w["root"]
    }

    ; The operations that take the flow from the result of Apply(raw, ops) back to raw.
    static Inverse(raw, ops) {
        return FlowPatch.Diff(FlowPatch.Apply(raw, ops), raw)
    }

    ; The operations that change `from` into `to` (both flows as Maps; `to` must be a valid flow). The order is chosen so
    ; that each operation sees a state in which its rules hold. ElementIDCounter is not part of it.
    static Diff(from, to) {
        ops := []
        fe := from["allElements"], te := to["allElements"]
        fc := from["allConnections"], tc := to["allConnections"]
        ; The default of an element that goes is cleared first, so that its removal promotes no other trigger.
        for id, el in fe {
            if (!te.Has(id) && FlowPatch._IsManualMap(el) && FlowPatch._Truthy(el.Get(FlowPatch.DEFAULT_KEY, "")))
                ops.Push(Map("op", "element.update", "id", id, "fields", Map(FlowPatch.DEFAULT_KEY, Json.False)))
        }
        for id in fc {
            if (!tc.Has(id))
                ops.Push(Map("op", "connection.remove", "id", id))
        }
        for id in fe {
            if (!te.Has(id))
                ops.Push(Map("op", "element.remove", "id", id))
        }
        for id, el in te {
            if (fe.Has(id)) {
                fields := FlowPatch._FieldsDiff(fe[id], el, true)
                if (fields.Count)
                    ops.Push(Map("op", "element.update", "id", id, "fields", fields))
            }
        }
        for id, el in te {
            if (!fe.Has(id))
                ops.Push(Map("op", "element.add", "element", FlowPatch._Copy(el)))
        }
        for id, c in tc {
            if (fc.Has(id)) {
                fields := FlowPatch._FieldsDiff(fc[id], c, false)
                if (fields.Count)
                    ops.Push(Map("op", "connection.update", "id", id, "fields", fields))
            }
        }
        for id, c in tc {
            if (!fc.Has(id))
                ops.Push(Map("op", "connection.add", "connection", FlowPatch._Copy(c)))
        }
        settings := FlowPatch._SettingsDiff(from.Get(FlowPatch.SETTINGS_KEY, ""), to.Get(FlowPatch.SETTINGS_KEY, ""))
        if (settings.Count)
            ops.Push(Map("op", "flow.settings", "settings", settings))
        return ops
    }

    ; --- dispatch ----------------------------------------------------------------------------------------------------

    static _Run(w, i, op) {
        if (!(op is Map) || !op.Has("op") || IsObject(op["op"]))
            throw AhfError("patch operation " i " needs an 'op' field", ErrCode.BAD_PAYLOAD)
        name := String(op["op"])
        if (!FlowPatch.OPS.Has(name))
            throw AhfError("unknown patch operation '" name "'", ErrCode.BAD_PAYLOAD)
        if (name = "element.add")
            FlowPatch._ElementAdd(w, i, name, op)
        else if (name = "element.update")
            FlowPatch._ElementUpdate(w, i, name, op)
        else if (name = "element.remove")
            FlowPatch._ElementRemove(w, i, name, op)
        else if (name = "connection.add")
            FlowPatch._ConnectionAdd(w, i, name, op)
        else if (name = "connection.update")
            FlowPatch._ConnectionUpdate(w, i, name, op)
        else if (name = "connection.remove")
            FlowPatch._ConnectionRemove(w, i, name, op)
        else
            FlowPatch._FlowSettings(w, i, name, op)
    }

    ; --- the operations ----------------------------------------------------------------------------------------------

    static _ElementAdd(w, i, name, op) {
        el := FlowPatch._Map(op, "element", i, name)
        id := FlowPatch._Text(el, "ID", i, name)
        if (!RegExMatch(id, FlowPatch.ELEMENT_ID_RE))
            FlowPatch._Fail(i, name, "'" id "' is not an element ID (element and ten digits)")
        if (w["root"]["allElements"].Has(id))
            FlowPatch._Fail(i, name, "element '" id "' exists already")
        FlowPatch._CheckElementShape(el, i, name, id)
        copy := FlowPatch._Copy(el)
        FlowPatch._ElsW(w)[id] := copy
        w["owned"]["el " id] := 1
        w["touchedEls"][id] := 1
        FlowPatch._BumpCounter(w, id)
        if (FlowPatch._IsManualMap(copy) && FlowPatch._Truthy(copy.Get(FlowPatch.DEFAULT_KEY, "")))
            FlowPatch._ClearDefaults(w, id)
    }

    static _ElementUpdate(w, i, name, op) {
        id := FlowPatch._Text(op, "id", i, name)
        if (!w["root"]["allElements"].Has(id))
            FlowPatch._Fail(i, name, "element '" id "' does not exist")
        fields := FlowPatch._Map(op, "fields", i, name)
        if (fields.Has("ID") && String(fields["ID"]) != id)
            FlowPatch._Fail(i, name, "the ID of an element cannot be changed")
        el := FlowPatch._ElW(w, id)
        ; pars first: a changed parameter loses its entry in the migration list (ARCHITECTURE 7); then the other keys
        if (fields.Has("pars")) {
            pv := fields["pars"]
            if (pv == Json.Null) {
                if (el.Has("pars"))
                    el.Delete("pars")
            } else {
                if (!(pv is Map))
                    FlowPatch._Fail(i, name, "'pars' must be an object")
                pars := (el.Has("pars") && el["pars"] is Map) ? el["pars"].Clone() : FlowPatch._NewMap()
                changed := []
                for par, v in pv {
                    had := pars.Has(par)
                    if (v == Json.Null) {
                        if (had) {
                            pars.Delete(par)     ; had: the key exists
                            changed.Push(par)
                        }
                    } else if (!had || !FlowPatch._Same(pars[par], v)) {
                        pars[par] := FlowPatch._Copy(v)
                        changed.Push(par)
                    }
                }
                el["pars"] := pars
                for par in changed
                    FlowPatch._DropMigration(el, par)
            }
        }
        for key, v in fields {
            if (key = "pars" || key = "ID")
                continue
            if (v == Json.Null) {
                if (el.Has(key))
                    el.Delete(key)
            } else {
                el[key] := FlowPatch._Copy(v)
            }
        }
        FlowPatch._CheckElementShape(el, i, name, id)
        w["touchedEls"][id] := 1
        if (fields.Has(FlowPatch.DEFAULT_KEY) && FlowPatch._IsManualMap(el)
            && FlowPatch._Truthy(el.Get(FlowPatch.DEFAULT_KEY, "")))
            FlowPatch._ClearDefaults(w, id)
    }

    static _ElementRemove(w, i, name, op) {
        id := FlowPatch._Text(op, "id", i, name)
        els := w["root"]["allElements"]
        if (!els.Has(id))
            FlowPatch._Fail(i, name, "element '" id "' does not exist")
        wasDefault := FlowPatch._IsManualMap(els[id]) && FlowPatch._Truthy(els[id].Get(FlowPatch.DEFAULT_KEY, ""))
        FlowPatch._ElsW(w).Delete(id)
        FlowPatch._Forget(w["owned"], "el " id)
        FlowPatch._Forget(w["touchedEls"], id)
        doomed := []
        for cid, c in w["root"]["allConnections"] {
            if (c.Get("from", "") = id || c.Get("to", "") = id)
                doomed.Push(cid)
        }
        if (doomed.Length) {
            cons := FlowPatch._ConsW(w)
            for cid in doomed
                cons.Delete(cid)
        }
        if (wasDefault && !FlowPatch._HasDefault(w)) {
            for eid in FlowPatch._SortedKeys(w["root"]["allElements"]) {
                if (FlowPatch._IsManualMap(w["root"]["allElements"][eid])) {
                    promoted := FlowPatch._ElW(w, eid)
                    promoted[FlowPatch.DEFAULT_KEY] := Json.True
                    break
                }
            }
        }
    }

    static _ConnectionAdd(w, i, name, op) {
        c := FlowPatch._Map(op, "connection", i, name)
        id := FlowPatch._Text(c, "ID", i, name)
        if (!RegExMatch(id, FlowPatch.CONNECTION_ID_RE))
            FlowPatch._Fail(i, name, "'" id "' is not a connection ID (connection and ten digits)")
        if (w["root"]["allConnections"].Has(id))
            FlowPatch._Fail(i, name, "connection '" id "' exists already")
        FlowPatch._Text(c, "from", i, name)
        FlowPatch._Text(c, "to", i, name)
        FlowPatch._Text(c, "ConnectionType", i, name)
        FlowPatch._ConsW(w)[id] := FlowPatch._Copy(c)
        w["owned"]["con " id] := 1
        w["touchedCons"][id] := 1
        FlowPatch._BumpCounter(w, id)
    }

    static _ConnectionUpdate(w, i, name, op) {
        id := FlowPatch._Text(op, "id", i, name)
        if (!w["root"]["allConnections"].Has(id))
            FlowPatch._Fail(i, name, "connection '" id "' does not exist")
        fields := FlowPatch._Map(op, "fields", i, name)
        if (fields.Has("ID") && String(fields["ID"]) != id)
            FlowPatch._Fail(i, name, "the ID of a connection cannot be changed")
        c := FlowPatch._ConW(w, id)
        for key, v in fields {
            if (key = "ID")
                continue
            if (v == Json.Null) {
                if (c.Has(key))
                    c.Delete(key)
            } else {
                c[key] := FlowPatch._Copy(v)
            }
        }
        w["touchedCons"][id] := 1
    }

    static _ConnectionRemove(w, i, name, op) {
        id := FlowPatch._Text(op, "id", i, name)
        if (!w["root"]["allConnections"].Has(id))
            FlowPatch._Fail(i, name, "connection '" id "' does not exist")
        FlowPatch._ConsW(w).Delete(id)
        FlowPatch._Forget(w["owned"], "con " id)
        FlowPatch._Forget(w["touchedCons"], id)
    }

    static _FlowSettings(w, i, name, op) {
        settings := FlowPatch._Map(op, "settings", i, name)
        if (op.Has("view") && !(op["view"] == Json.True || op["view"] == Json.False || op["view"] == 1 || op["view"] == 0))
            FlowPatch._Fail(i, name, "'view' must be true or false")
        current := w["root"].Get(FlowPatch.SETTINGS_KEY, "")
        target := (current is Map) ? current.Clone() : FlowPatch._NewMap()
        for key, v in settings {
            if (v == Json.Null) {
                if (target.Has(key))
                    target.Delete(key)
            } else {
                target[key] := FlowPatch._Copy(v)
            }
        }
        w["root"][FlowPatch.SETTINGS_KEY] := target
    }

    ; --- checks ------------------------------------------------------------------------------------------------------

    ; The shape of an element that is added or changed: a known kind, a class, parameters as an object.
    static _CheckElementShape(el, i, name, id) {
        kind := FlowPatch._KindOf(el)
        if (!FlowPatch.KINDS.Has(kind))
            FlowPatch._Fail(i, name, "element '" id "' has an unknown type '" kind "'")
        if (!el.Has("class") || IsObject(el["class"]) || el["class"] = "")
            FlowPatch._Fail(i, name, "element '" id "' needs a class")
        if (el.Has("pars") && !(el["pars"] is Map))
            FlowPatch._Fail(i, name, "'pars' of element '" id "' must be an object")
    }

    ; The checks of the touched connections and elements, on the final state of the flow.
    static _CheckTouched(w) {
        els := w["root"]["allElements"]
        cons := w["root"]["allConnections"]
        for cid in FlowPatch._SortedKeys(w["touchedCons"]) {
            if (cons.Has(cid))
                FlowPatch._CheckConnection(els, cons, cid)
        }
        for eid in FlowPatch._SortedKeys(w["touchedEls"]) {
            if (!els.Has(eid) || FlowPatch._KindOf(els[eid]) != "trigger")
                continue
            for cid, c in cons {
                if (c.Get("to", "") = eid)
                    throw AhfError("patch: connection '" cid "' leads into the trigger '" eid "'", ErrCode.BAD_PAYLOAD)
            }
        }
    }

    static _CheckConnection(els, cons, cid) {
        c := cons[cid]
        from := FlowPatch._Scalar(c.Get("from", ""))
        to := FlowPatch._Scalar(c.Get("to", ""))
        where := "patch: connection '" cid "': "
        if (!els.Has(from))
            throw AhfError(where "the start element '" from "' does not exist", ErrCode.BAD_PAYLOAD)
        if (!els.Has(to))
            throw AhfError(where "the end element '" to "' does not exist", ErrCode.BAD_PAYLOAD)
        if (from = to)
            throw AhfError(where "a connection from an element to itself", ErrCode.BAD_PAYLOAD)
        if (FlowPatch._KindOf(els[to]) = "trigger")
            throw AhfError(where "a connection leads into the trigger '" to "'", ErrCode.BAD_PAYLOAD)
        ctype := StrLower(FlowPatch._Scalar(c.Get("ConnectionType", "")))
        if (!FlowPatch.CONNECTION_TYPES.Has(ctype))
            throw AhfError(where "unknown connection type '" FlowPatch._Scalar(c.Get("ConnectionType", "")) "'", ErrCode.BAD_PAYLOAD)
        fromPart := FlowPatch._Scalar(c.Get("fromPart", ""))
        toPart := FlowPatch._Scalar(c.Get("toPart", ""))
        for oid, other in cons {
            if (oid = cid)
                continue
            if (FlowPatch._Scalar(other.Get("from", "")) = from && FlowPatch._Scalar(other.Get("to", "")) = to
                && StrLower(FlowPatch._Scalar(other.Get("ConnectionType", ""))) = ctype
                && FlowPatch._Scalar(other.Get("fromPart", "")) = fromPart
                && FlowPatch._Scalar(other.Get("toPart", "")) = toPart)
                throw AhfError(where "an identical connection exists ('" oid "')", ErrCode.BAD_PAYLOAD)
        }
    }

    ; --- copy on write -----------------------------------------------------------------------------------------------

    ; The elements map of the new root, copied once per Apply, when an operation first writes to it.
    static _ElsW(w) {
        if (!w["owned"].Has("els")) {
            w["root"]["allElements"] := w["root"]["allElements"].Clone()
            w["owned"]["els"] := 1
        }
        return w["root"]["allElements"]
    }

    static _ConsW(w) {
        if (!w["owned"].Has("cons")) {
            w["root"]["allConnections"] := w["root"]["allConnections"].Clone()
            w["owned"]["cons"] := 1
        }
        return w["root"]["allConnections"]
    }

    ; One element of the new root, copied once per Apply.
    static _ElW(w, id) {
        els := FlowPatch._ElsW(w)
        key := "el " id
        if (!w["owned"].Has(key)) {
            els[id] := els[id].Clone()
            w["owned"][key] := 1
        }
        return els[id]
    }

    static _ConW(w, id) {
        cons := FlowPatch._ConsW(w)
        key := "con " id
        if (!w["owned"].Has(key)) {
            cons[id] := cons[id].Clone()
            w["owned"][key] := 1
        }
        return cons[id]
    }

    ; Clears DefaultTrigger on every manual trigger except exceptId that has it (as v1 Element_setDefaultTrigger).
    static _ClearDefaults(w, exceptId) {
        for eid in FlowPatch._SortedKeys(w["root"]["allElements"]) {
            if (eid = exceptId)
                continue
            el := w["root"]["allElements"][eid]
            if (FlowPatch._IsManualMap(el) && FlowPatch._Truthy(el.Get(FlowPatch.DEFAULT_KEY, "")))
                FlowPatch._ElW(w, eid)[FlowPatch.DEFAULT_KEY] := Json.False
        }
    }

    static _HasDefault(w) {
        for eid, el in w["root"]["allElements"] {
            if (FlowPatch._IsManualMap(el) && FlowPatch._Truthy(el.Get(FlowPatch.DEFAULT_KEY, "")))
                return true
        }
        return false
    }

    static _BumpCounter(w, id) {
        if (!RegExMatch(id, "\d{10}$", &digits))
            return
        n := Integer(digits[0])
        root := w["root"]
        cur := root.Get(FlowPatch.COUNTER_KEY, 1)
        curNum := IsInteger(cur) ? Integer(cur) : 1
        if (n + 1 > curNum)
            root[FlowPatch.COUNTER_KEY] := (Type(cur) = "String") ? String(n + 1) : n + 1
    }

    static _DropMigration(el, par) {
        if (!el.Has(FlowPatch.MIGRATION_KEY) || !(el[FlowPatch.MIGRATION_KEY] is Array))
            return
        kept := []
        for entry in el[FlowPatch.MIGRATION_KEY] {
            if (!(entry is Map) || FlowPatch._Scalar(entry.Get("par", "")) != par)
                kept.Push(entry)
        }
        if (kept.Length)
            el[FlowPatch.MIGRATION_KEY] := kept
        else
            el.Delete(FlowPatch.MIGRATION_KEY)
    }

    ; --- diff helpers ------------------------------------------------------------------------------------------------

    static _FieldsDiff(f, t, isElement) {
        fields := Map()
        for key, v in t {
            if (key = "ID" || (isElement && key = "pars"))
                continue
            if (!f.Has(key) || !FlowPatch._Same(f[key], v))
                fields[key] := FlowPatch._Copy(v)
        }
        for key, v in f {
            if (key = "ID" || (isElement && key = "pars"))
                continue
            if (!t.Has(key))
                fields[key] := Json.Null
        }
        if (!isElement)
            return fields
        fp := f.Get("pars", "")
        tp := t.Get("pars", "")
        if ((fp is Map) && (tp is Map)) {
            pd := Map()
            for par, v in tp {
                if (!fp.Has(par) || !FlowPatch._Same(fp[par], v))
                    pd[par] := FlowPatch._Copy(v)
            }
            for par, v in fp {
                if (!tp.Has(par))
                    pd[par] := Json.Null
            }
            if (pd.Count)
                FlowPatch._SetPars(fields, pd, t)
        } else if (tp is Map) {
            FlowPatch._SetPars(fields, FlowPatch._Copy(tp), t)
        } else if (fp is Map) {
            fields["pars"] := Json.Null
        }
        return fields
    }

    ; A change of pars also sets the migration list explicitly: the parameter entries that the change drops are
    ; restored by the list of the target.
    static _SetPars(fields, pars, t) {
        fields["pars"] := pars
        fields[FlowPatch.MIGRATION_KEY] := t.Has(FlowPatch.MIGRATION_KEY) ? FlowPatch._Copy(t[FlowPatch.MIGRATION_KEY]) : Json.Null
    }

    static _SettingsDiff(fs, ts) {
        out := Map()
        if (!(ts is Map))
            return out
        fs := (fs is Map) ? fs : FlowPatch._NewMap()
        for key, v in ts {
            if (!fs.Has(key) || !FlowPatch._Same(fs[key], v))
                out[key] := FlowPatch._Copy(v)
        }
        for key, v in fs {
            if (!ts.Has(key))
                out[key] := Json.Null
        }
        return out
    }

    ; --- small helpers -----------------------------------------------------------------------------------------------

    ; Map.Delete throws on a missing key (AHK v2): delete only what is there.
    static _Forget(m, key) {
        if (m.Has(key))
            m.Delete(key)
    }

    static _Fail(i, name, reason) {
        throw AhfError("patch operation " i " (" name "): " reason, ErrCode.BAD_PAYLOAD)
    }

    static _Map(holder, key, i, name) {
        if (!holder.Has(key) || !(holder[key] is Map))
            FlowPatch._Fail(i, name, "'" key "' must be an object")
        return holder[key]
    }

    ; A required text field: a value that is not empty.
    static _Text(holder, key, i, name) {
        if (!holder.Has(key) || IsObject(holder[key]) || holder[key] = "")
            FlowPatch._Fail(i, name, "'" key "' is missing")
        return String(holder[key])
    }

    static _Scalar(v) => IsObject(v) ? "" : String(v)

    static _KindOf(el) => StrLower(FlowPatch._Scalar(el.Get("type", "")))

    static _IsManualMap(el) => FlowPatch._KindOf(el) = "trigger" && StrLower(FlowPatch._Scalar(el.Get("class", ""))) = "trigger_manual"

    ; True for JSON true, 1, "1" and "true" (the forms that v1 files and the wire use).
    static _Truthy(v) => (v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true")))

    ; Equal values with their types: a changed case or a changed type is a change.
    static _Same(a, b) {
        if (IsObject(a) || IsObject(b))
            return IsObject(a) && IsObject(b) && (a == b || Json.Stringify(a) == Json.Stringify(b))
        return Type(a) = Type(b) && a == b
    }

    ; A deep copy of a parsed value; Maps keep their case sensitivity.
    static _Copy(value) {
        if (value is Map) {
            m := Map()
            m.CaseSense := value.CaseSense
            for k, v in value
                m[k] := FlowPatch._Copy(v)
            return m
        }
        if (value is Array) {
            a := []
            for v in value
                a.Push(FlowPatch._Copy(v))
            return a
        }
        return value
    }

    static _NewMap() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    static _SortedKeys(m) {
        keys := []
        for k in m
            keys.Push(k)
        return keys
    }
}
