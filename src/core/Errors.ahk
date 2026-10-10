#Requires AutoHotkey v2.0
; Error classes and error codes shared by all processes (doc/PROTOKOLL.md section 2).
; Every exception carries a `code`. Subclasses preset it; AhfError takes it as second argument.

; Error codes as static properties (no global variables, see doc/KONVENTIONEN.md section 1).
class ErrCode {
    static TIMEOUT := "timeout"
    static UNKNOWN_TYPE := "unknown_type"
    static BAD_PAYLOAD := "bad_payload"
    static NOT_FOUND := "not_found"
    static CONFLICT := "conflict"
    static BUSY := "busy"
    static DENIED := "denied"
    static INTERNAL := "internal"
    static PEER_GONE := "peer_gone"
    static SHUTTING_DOWN := "shutting_down"
    ; Codes outside the protocol list, used for local errors only.
    static BAD_JSON := "bad_json"
    static BAD_ARGS := "bad_args"
    static EXCEPTION := "exception"
}

; Base class. Message is the Error.Message property, code is set from the constructor.
class AhfError extends Error {
    code := ErrCode.INTERNAL

    __New(message := "", code := "", extra := "") {
        super.__New(message, , extra)
        if (code != "")
            this.code := code
    }
}

class ProtocolError extends AhfError {
    code := ErrCode.BAD_PAYLOAD
}

class AhfTimeoutError extends AhfError {
    code := ErrCode.TIMEOUT
}

class ElementError extends AhfError {
    code := ErrCode.EXCEPTION
}

class JsonError extends AhfError {
    code := ErrCode.BAD_JSON
}
