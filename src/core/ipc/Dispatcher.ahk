#Requires AutoHotkey v2.0
#Include ..\Errors.ahk
#Include Message.ahk
#Include Deferred.ahk

; Routes messages to handlers by type prefix (doc/PROTOCOL.md, sections 2 and 6).
; The longest registered prefix wins: On("cmd.", f) takes all commands, On("cmd.flow.", g) the flow ones.
; Handlers are function objects, not static methods (doc/HOW-TO.md, "Statische Methode ist kein Callback"):
;
;   d := Dispatcher()
;   d.On("cmd.flow.start", (msg) => Map("instanceId", "i1"))
;   d.On("evt.", (msg) => 0)                 ; a handler may return nothing
;   result := d.Invoke(msg)                  ; always a Map with ok, never throws
;
; Invoke gives back the payload for the answer: the handler's Map (ok added as true when missing),
; {ok:false, error:{code:"unknown_type"}} when no prefix matches, or {ok:false, error:{code, message}}
; when the handler throws (AhfError keeps its code, any other error becomes "internal").
class Dispatcher {
    __New() {
        this._handlers := Map()
    }

    ; Registers handler for every type that starts with typePrefix. Registering the same prefix again replaces it.
    On(typePrefix, handler) {
        if (typePrefix = "" || !IsObject(handler))
            throw AhfError("Dispatcher.On: needs a type prefix and a function", ErrCode.BAD_ARGS)
        this._handlers[typePrefix] := handler
    }

    ; Returns the handler for a message type (longest matching prefix), or "" if none matches.
    Find(msgType) {
        best := ""
        bestLen := -1
        for prefix, handler in this._handlers {
            n := StrLen(prefix)
            if (n > bestLen && SubStr(msgType, 1, n) == prefix) {
                best := handler
                bestLen := n
            }
        }
        return best
    }

    ; Calls the handler for msg and returns the payload Map for the answer. Never throws.
    Invoke(msg) {
        handler := this.Find(msg.type)
        if (!IsObject(handler))
            return Map("ok", false, "error", Map("code", ErrCode.UNKNOWN_TYPE, "message", "no handler for " msg.type))
        try {
            result := handler(msg)
        } catch as e {
            code := (e is AhfError) ? e.code : ErrCode.INTERNAL
            return Map("ok", false, "error", Map("code", code, "message", Type(e) ": " e.Message))
        }
        ; The handler answers later with Peer.Reply (WI-0012): pass the marker through unchanged.
        if (result is Deferred)
            return result
        ; A handler without a return statement gives "" (nothing); any other non-Map value is a bug.
        if (!IsObject(result) && result == "")
            return Map("ok", true)
        if (!IsObject(result) || Type(result) != "Map")
            return Map("ok", false, "error", Map("code", ErrCode.INTERNAL
                , "message", "handler for " msg.type " must return a Map or nothing"))
        if (!result.Has("ok"))
            result["ok"] := true
        return result
    }
}
