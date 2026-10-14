#Requires AutoHotkey v2.0

; Error codes as static properties (no global variables, see doc/CONVENTIONS.md section 1).
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
    static GONE := "gone"               ; the execution or instance of a request has ended (WI-50, PROTOCOL 4.5)
    ; Codes outside the protocol list, used for local errors only.
    static BAD_JSON := "bad_json"
    static BAD_ARGS := "bad_args"
    static EXCEPTION := "exception"
}
