#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Json.ahk
#Include ..\..\..\core\Lang.ahk

; The view of the debug window (REQ-DBG-060, WI-0056; ELEMENT-API-V2 3.4). The window (Dialogs.DebugWindow) shows and
; changes the variables of the branch through this object only, so the product window and the test provider work on the
; same functions. All calls go through the context of the element: in a worker they are requests to the engine
; (ARCHITECTURE R0004, PROTOCOL 4.5), so a change is the one of the variable model (global and static variables go to the
; permanent store, REQ-VAR-050).
;
;   Rows()                    the list of the window: an Array of Maps text, name and scope. A group heading has name "".
;   Text(name, convert)       the value as text: an object as JSON, special characters escaped with convert.
;                             Every text that the window shows comes from here (a mask for secret values, REQ-SEC-040,
;                             goes in one place).
;   Type(name)                "object", "normal" or "" (does not exist).
;   Write(name, text, asObject, convert)
;                             sets the value: asObject turns the text into an object (JSON), convert unescapes the
;                             special characters. Returns "" or the error text, and then changes nothing.
;   Delete(name)              removes the variable; returns 1 if it existed.
;   ReadOnly                  true: the window only shows (REQ-USE-080); the window then offers no change.
class DebugOps {
    static SCOPES := ["loop", "thread", "instance", "static", "global"]
    static LABELS := Map("loop", "Loop variables", "thread", "Thread variables", "instance", "Instance variables"
        , "static", "Static variables", "global", "Global variables")

    __New(ctx, readOnly := false) {
        this.ctx := ctx
        this.ReadOnly := readOnly
    }

    Rows() {
        rows := []
        for scope in DebugOps.SCOPES {
            names := this.ctx.ListVars(scope)
            if (names.Length = 0)
                continue
            rows.Push(Map("text", "--- " Lang(DebugOps.LABELS[scope]) " ---", "name", "", "scope", ""))
            for name in names
                rows.Push(Map("text", name, "name", name, "scope", scope))
        }
        return rows
    }

    Text(name, convert := false) {
        value := this.ctx.GetVar(name, "")
        text := IsObject(value) ? Json.Stringify(value, 2) : String(value)
        return convert ? DebugOps.Escape(text) : text
    }

    Type(name) => this.ctx.GetVarType(name)

    Write(name, text, asObject := false, convert := false) {
        if (convert) {
            try {
                text := DebugOps.Unescape(text)
            } catch as e {
                return "The text has an invalid escape sequence: " e.Message
            }
        }
        value := text
        if (asObject) {
            try {
                value := Json.Parse(text)
            } catch as e {
                return "The text is not a valid object (JSON): " e.Message
            }
            if (!IsObject(value))
                return "The text is not an object: use { } for a Map or [ ] for a list."
        }
        ; a loop or thread variable (an A_ name) is set where it lives; the name alone would decide another scope
        location := this.ctx.GetVarLocation(name)
        if (location != "loop" && location != "thread")
            location := ""
        if (!this.ctx.SetVar(name, value, location))
            return "The variable '" name "' could not be changed."
        return ""
    }

    Delete(name) => this.ctx.DeleteVar(name)

    ; Escapes a backslash, the control characters and every character outside printable ASCII (\uXXXX), so the text
    ; can be read and edited in one line. Unescape is the reverse.
    static Escape(text) {
        out := ""
        for ch in StrSplit(text) {
            code := Ord(ch)
            if (ch = "\")
                out .= "\\"
            else if (ch = "`r")
                out .= "\r"
            else if (ch = "`n")
                out .= "\n"
            else if (ch = "`t")
                out .= "\t"
            else if (code < 0x20 || code > 0x7E)
                out .= Format("\u{:04X}", code)
            else
                out .= ch
        }
        return out
    }

    ; The reverse of Escape. Throws ValueError for a \ that starts no known sequence.
    static Unescape(text) {
        out := ""
        i := 1
        n := StrLen(text)
        while (i <= n) {
            ch := SubStr(text, i, 1)
            if (ch != "\") {
                out .= ch
                i += 1
                continue
            }
            if (i = n)
                throw ValueError("a backslash at the end")
            nxt := SubStr(text, i + 1, 1)
            switch nxt, "Off" {
                case "\": out .= "\"
                case "r": out .= "`r"
                case "n": out .= "`n"
                case "t": out .= "`t"
                case "u":
                    hex := SubStr(text, i + 2, 4)
                    if (!RegExMatch(hex, "^[0-9A-Fa-f]{4}$"))
                        throw ValueError("\u needs four hexadecimal digits")
                    out .= Chr("0x" hex)
                    i += 4
                default:
                    throw ValueError("unknown escape \" nxt)
            }
            i += 2
        }
        return out
    }
}
