#Requires AutoHotkey v2.0
#Include ..\..\core\Json.ahk
#Include VarValues.ahk

; JSON text of a variable value, in the form of v1 Jxon_Dump (WI-40, v1 Var_replaceVariables with the option
; ConvertObjectToString). A Map with exactly the keys 1..n is written as an array; any other Map as an object with
; its keys in the order of the Map (Integer keys ascending, then the texts sorted without case, as in v1).
; With indent n > 0 every value is on its own line with n spaces per level, as Jxon_Dump(value, 2) wrote.
; Differences from v1 (doc/MIGRATION.md): "/" is not escaped, and a Float is written as a JSON number.
class VarJson {
    static Stringify(value, indent := 0) {
        out := ""
        VarJson._Emit(value, indent, 0, &out)
        return out
    }

    static _Emit(value, indent, level, &out) {
        if (value is Map) {
            if (value.Count = 0) {
                out .= "{}"
                return
            }
            isList := VarValues.IsList(value)
            out .= isList ? "[" : "{"
            for key, item in value {
                if (A_Index > 1)
                    out .= ","
                VarJson._Newline(indent, level + 1, &out)
                if (!isList)
                    out .= Json.Quote(String(key)) . ((indent > 0) ? ": " : ":")
                VarJson._Emit(item, indent, level + 1, &out)
            }
            VarJson._Newline(indent, level, &out)
            out .= isList ? "]" : "}"
            return
        }
        switch Type(value) {
            case "Integer":
                out .= String(value)
            case "Float":
                ; inf and nan have no JSON form: they are written as their text.
                out .= (value - value = 0) ? Json.FormatFloat(value) : Json.Quote(String(value))
            default:
                out .= Json.Quote(IsObject(value) ? "" : String(value))
        }
    }

    static _Newline(indent, level, &out) {
        if (indent <= 0)
            return
        out .= "`n"
        loop indent * level
            out .= " "
    }
}
