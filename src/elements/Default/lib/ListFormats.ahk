#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Json.ahk
#Include ..\lib\ListOps.ahk

; The conversion of lists to and from JSON for the elements Convert list to string and Convert string to list of the
; package Default (WI-0119). A list (a Map, lib/ListOps.ahk) with the keys 1 to n and nothing else is a JSON array, as v1
; (Jxon) wrote it; every other list is a JSON object with its keys as text. Values are converted recursively.
; The reading gives lists again: an array gets the keys 1 to n, an object the keys of ListOps.NormKey. A JSON null
; is the empty text (v1 gave the empty text too). Pure functions, no ctx and no I/O.
class ListFormats {
    ; The list as a value that Json.Stringify writes: an Array for a sequence, a Map with text keys otherwise.
    static ToPlain(value) {
        if (!(value is Map))
            return (value is Array) ? ListFormats._ArrayToPlain(value) : value
        if (ListFormats.IsSequence(value)) {
            out := []
            loop value.Count
                out.Push(ListFormats.ToPlain(value[A_Index]))
            return out
        }
        out := Map()
        for key, item in value
            out[String(key)] := ListFormats.ToPlain(item)
        return out
    }

    ; The value read by Json.Parse as a list (or a value of a list): Arrays and Maps become lists.
    static FromPlain(value) {
        if (value == Json.Null)
            return ""
        if (value is Array) {
            list := ListOps.NewList()
            for i, item in value
                list[i] := ListFormats.FromPlain(item)
            return list
        }
        if (value is Map) {
            list := ListOps.NewList()
            for key, item in value
                list[ListOps.NormKey(key)] := ListFormats.FromPlain(item)
            return list
        }
        return value
    }

    ; True if the list has the keys 1 to Count and no other key (an empty list is one).
    static IsSequence(m) {
        for key in m {
            if (Type(key) != "Integer")
                return false
        }
        loop m.Count {
            if (!m.Has(A_Index))
                return false
        }
        return true
    }

    static _ArrayToPlain(arr) {
        out := []
        for item in arr
            out.Push(ListFormats.ToPlain(item))
        return out
    }
}
