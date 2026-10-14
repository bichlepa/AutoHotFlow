#Requires AutoHotkey v2.0
#Include ..\..\core\Json.ahk

; Values of variables (WI-40, decision E28, doc/EXPRESSION-LANGUAGE.md section 18).
;
; A variable holds a text, a number (Integer or Float) or an object. An object is a Map with CaseSense "Off". There
; are no Arrays in variables: a list is a Map with the Integer keys 1..n, as in v1, where a list was an object with
; integer keys. A key that looks like a decimal integer ("1", "01", "-2") is stored as the Integer, so that
; list.1, list[1] and list["1"] are the same member (verified against the golden data of v1). A Map enumerates its
; Integer keys in ascending order and then its texts sorted without case, which is the order of v1.
;
; A value is copied when it goes into a variable (Import) and when an element reads it (Copy): one owner per datum.
class VarValues {
    ; Longest run of digits that is turned into an Integer key; a longer one would wrap around (doc/HOW-TO.md).
    static MAX_KEY_DIGITS := 18

    static NewMap() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    ; The key under which a member is stored: an Integer for an Integer or a text of decimal digits (with an
    ; optional minus), else the text. A Float key is its text.
    static NormKey(key) {
        if (Type(key) = "Integer")
            return key
        k := String(key)
        if (RegExMatch(k, "^-?[0-9]{1," VarValues.MAX_KEY_DIGITS "}$"))
            return Integer(k)
        return k
    }

    ; Returned by FindKey when there is no such member (an object, so it cannot be mistaken for a key).
    static NONE := Object()

    ; The key of the member of m that matches key (a text or a number), or NONE if there is none. A Map that did not
    ; come through Import (for example from object() in an expression) may hold "1" as a text; it is found as well.
    static FindKey(m, key) {
        k := VarValues.NormKey(key)
        if (m.Has(k))
            return k
        if (Type(k) = "Integer" && m.Has(String(k)))
            return String(k)
        return VarValues.NONE
    }

    ; A copy of a value as it is stored in a variable: Arrays become Maps with the keys 1..n, keys are normalized,
    ; Maps get CaseSense "Off". Texts and numbers are kept as they are. Other objects are refused (ValueError).
    static Import(value) {
        if (value is Map) {
            m := VarValues.NewMap()
            for key, item in value
                m[VarValues.NormKey(key)] := VarValues.Import(item)
            return m
        }
        if (value is Array) {
            m := VarValues.NewMap()
            for item in value
                m[A_Index] := VarValues.Import(IsSet(item) ? item : "")
            return m
        }
        if (IsObject(value)) {
            ; Parsed JSON (variable files, messages): null is the empty text, true and false are 1 and 0.
            if (value == Json.Null)
                return ""
            if (value == Json.True)
                return 1
            if (value == Json.False)
                return 0
            throw ValueError("a variable cannot hold a value of type " Type(value))
        }
        return value
    }

    ; A deep copy of a stored value.
    static Copy(value) {
        if (!(value is Map))
            return value
        m := VarValues.NewMap()
        for key, item in value
            m[key] := VarValues.Copy(item)
        return m
    }

    ; True if the Map has exactly the keys 1..n (n >= 1): it is written as a JSON array.
    static IsList(m) {
        n := m.Count
        if (n = 0)
            return false
        loop n {
            if (!m.Has(A_Index))
                return false
        }
        return true
    }

    ; The text of a value as it appears in a text (substitution, concatenation): objects give the empty text.
    static Text(value) {
        return IsObject(value) ? "" : String(value)
    }
}
