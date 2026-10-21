#Requires AutoHotkey v2.0

; The rules of a connection in the editor (WI-0100, REQ-EDT-070, v1 ui_MoveConnectionCheckAndCorrect): the types a connection
; may have for its start element, the default type, the part of a loop that an end is attached to, and the checks that refuse
; a connection before it is sent (a connection into a trigger, from an element to itself, an identical second connection).
; Pure data: no GUI, no engine. The texts of a refusal are language keys (Lang), shown in the status bar.
;
; A connection spec is a Map with from, to, type, fromPart and toPart (strings, "" for none). NEW stands for the element that
; the gesture creates: its ID comes with the patch, so the checks skip what only the real ID could show.
class ConnectionRules {
    static NEW := "#new"

    ; The types a connection from an element of kind may have, as [id, labelKey] pairs in the order of the selector: a
    ; condition has yes, no and exception (v1 Condition); any other element normal and exception.
    static Options(kind) => (StrLower(kind) = "condition") ? [["yes", "Yes"], ["no", "No"], ["exception", "Exception"]]
        : [["normal", "Normal"], ["exception", "Exception"]]

    ; True when type is one of the options of kind (any case, as v1 compares them).
    static Valid(kind, type) {
        t := StrLower(String(type))
        for option in ConnectionRules.Options(kind) {
            if (option[1] = t)
                return true
        }
        return false
    }

    ; The type a new connection from an element of kind gets by default (the first choice of the selector: yes for a condition).
    static Default(kind) => (StrLower(kind) = "condition") ? "yes" : "normal"

    ; The part of a loop at the end of a connection that goes to it (v1: parts 1 and 2 the head, 3 the foot, 4 the break field;
    ; part 0 is a new loop, which gets the head). "" for an element that is not a loop.
    static ToPart(kind, part) {
        if (StrLower(kind) != "loop")
            return ""
        if (part = 3)
            return "TAIL"
        if (part = 4)
            return "BREAK"
        return "HEAD"
    }

    ; The part of a loop a connection starts from (v1: the head for parts 1 and 2; the foot for 3 and 4, because the break field
    ; cannot start a connection; part 0 is a new loop, which gets the foot). "" for an element that is not a loop.
    static FromPart(kind, part) {
        if (StrLower(kind) != "loop")
            return ""
        return (part = 1 || part = 2) ? "HEAD" : "TAIL"
    }

    ; The refusal of a connection as a language key, or "" when it may be made. root is the flow (a Map with allElements and
    ; allConnections); exceptId is the connection that this one replaces (its old state is not a duplicate).
    static Refusal(root, spec, exceptId := "") {
        from := String(spec["from"])
        to := String(spec["to"])
        if (to != ConnectionRules.NEW) {
            if (StrLower(ConnectionRules.KindOf(root, to)) = "trigger")
                return "You cannot connect to trigger!"
        }
        if (from = to)
            return "The connection cannot start and end on the same element!"
        if (to = ConnectionRules.NEW)
            return ""
        type := StrLower(String(spec["type"]))
        fromPart := String(spec["fromPart"])
        toPart := String(spec["toPart"])
        for id, other in root["allConnections"] {
            if (id = exceptId)
                continue
            if (String(other.Get("from", "")) = from && String(other.Get("to", "")) = to
                && StrLower(String(other.Get("ConnectionType", ""))) = type
                && String(other.Get("fromPart", "")) = fromPart && String(other.Get("toPart", "")) = toPart)
                return "This connection already exists!"
        }
        return ""
    }

    ; The kind of an element of the flow in lower case ("" when there is no such element).
    static KindOf(root, id) {
        if (!(root is Map) || !root["allElements"].Has(id))
            return ""
        return StrLower(String(root["allElements"][id].Get("type", "")))
    }
}
