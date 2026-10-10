#Requires AutoHotkey v2.0
#Include ..\Errors.ahk
#Include ..\Json.ahk

; One protocol envelope (doc/PROTOCOL.md, section 2).
; The head fields are always written in the same order (to, from, id, type, corr, timeoutMs,
; payload), so a hub can read `to` from the first bytes without parsing the payload (ReadTo).
;
;   msg := Message("engine", "editor:Flow 1", "editor:Flow 1#17", "cmd.flow.start", Map("flowId", "Flow 1"))
;   text := msg.Serialize()
;   msg2 := Message.Parse(text)
;
; corr "" means null. timeoutMs 0 means the field is absent (it is only written for cmd.*).
; The property is called `type`; the parameter is `msgType` so that it does not shadow Type().
class Message {
    to := ""
    from := ""
    id := ""
    type := ""
    corr := ""
    timeoutMs := 0
    payload := ""

    __New(to := "", from := "", id := "", msgType := "", payload := "", corr := "", timeoutMs := 0) {
        this.to := to
        this.from := from
        this.id := id
        this.type := msgType
        this.corr := corr
        this.timeoutMs := timeoutMs
        this.payload := IsObject(payload) ? payload : Map()
    }

    ; Returns the envelope as one line of JSON with the head fields first.
    Serialize() {
        text := '{"to":' Json.Stringify(this.to)
            . ',"from":' Json.Stringify(this.from)
            . ',"id":' Json.Stringify(this.id)
            . ',"type":' Json.Stringify(this.type)
            . ',"corr":' (this.corr = "" ? "null" : Json.Stringify(this.corr))
        if (this.timeoutMs > 0)
            text .= ',"timeoutMs":' Integer(this.timeoutMs)
        return text ',"payload":' Json.Stringify(this.payload) "}"
    }

    ; Parses and validates one envelope. Throws ProtocolError (code bad_payload) on any problem.
    ; to, from, id and type must be non-empty strings, payload must be an object. corr may be a
    ; string or null (absent counts as null), timeoutMs a non-negative integer (absent counts as 0).
    static Parse(text) {
        try {
            data := Json.Parse(text)
        } catch as e {
            throw ProtocolError("envelope is not valid JSON: " e.Message)
        }
        if (Type(data) != "Map")
            throw ProtocolError("envelope must be a JSON object")
        to := Message._Head(data, "to")
        from := Message._Head(data, "from")
        id := Message._Head(data, "id")
        msgType := Message._Head(data, "type")
        if (!data.Has("payload") || Type(data["payload"]) != "Map")
            throw ProtocolError("envelope field 'payload' must be an object")
        corr := ""
        if (data.Has("corr") && !(data["corr"] == Json.Null)) {
            if (Type(data["corr"]) != "String")
                throw ProtocolError("envelope field 'corr' must be a string or null")
            corr := data["corr"]
        }
        timeoutMs := 0
        if (data.Has("timeoutMs")) {
            if (Type(data["timeoutMs"]) != "Integer" || data["timeoutMs"] < 0)
                throw ProtocolError("envelope field 'timeoutMs' must be a non-negative integer")
            timeoutMs := data["timeoutMs"]
        }
        return Message(to, from, id, msgType, data["payload"], corr, timeoutMs)
    }

    ; Returns the `to` field of a serialized envelope without parsing the rest.
    ; Only works for text that starts with the head fields in the order Serialize writes them.
    ; Throws ProtocolError if the text does not start with a non-empty "to" string.
    static ReadTo(text) {
        if (!RegExMatch(text, '^\s*\{\s*"to"\s*:\s*"((?:[^"\\]++|\\.)*+)"', &m))
            throw ProtocolError("envelope does not start with a 'to' field")
        raw := m[1]
        if (raw = "")
            throw ProtocolError("envelope field 'to' is empty")
        if (!InStr(raw, "\"))
            return raw
        try {
            return Json.Parse('"' raw '"')
        } catch as e {
            throw ProtocolError("envelope field 'to' has invalid escapes: " e.Message)
        }
    }

    static _Head(data, key) {
        if (!data.Has(key))
            throw ProtocolError("envelope field '" key "' is missing")
        value := data[key]
        if (Type(value) != "String" || value = "")
            throw ProtocolError("envelope field '" key "' must be a non-empty string")
        return value
    }
}
