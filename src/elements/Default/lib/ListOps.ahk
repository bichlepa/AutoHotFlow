#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The list operations of the package Default (WI-0053): one implementation for the list elements (New list, Add to list,
; Get list info, List contains element, Delete from list, Get index of element in list, Shuffle list) and for whatever
; needs them later (methods and functions of the script language, REQ-SCR-020, REQ-SCR-080).
;
; The list model (doc/EXPRESSION-LANGUAGE.md section 18.3, REQ-VAR-060): a list is a Map with CaseSense "Off". Its
; keys are Integers (the positions, usually 1..n, gaps are allowed) or texts. A key that looks like a decimal integer
; is the Integer ("1", "01" and 1 are one key, NormKey). The Map enumerates the Integer keys ascending and then the
; texts, which is the order of v1.
;
; Copy semantics (REQ-VAR-060) live in the variable model and nowhere else: ctx.GetVar returns a copy, ctx.SetVar stores
; a copy. So every function here changes the Map that it is given in place; an element reads the list with
; ListOps.Load, changes the copy and writes it back with ctx.SetVar. Nothing here keeps a reference. (If references
; are added later, REQ-VAR-150, only Load and the write-back of the elements change.)
;
; The functions are pure (no ctx, no I/O) except Load. They throw ElementError with the texts of v1.
class ListOps {
    ; The key under which a member is stored: an Integer for an Integer or a text of decimal digits (with an optional
    ; minus, at most 18 digits), else the text. The same rule as VarValues.NormKey of the engine; the editor, which
    ; also holds the element classes, does not have that class.
    static NormKey(key) {
        if (Type(key) = "Integer")
            return key
        k := String(key)
        if (RegExMatch(k, "^-?[0-9]{1,18}$"))
            return Integer(k)
        return k
    }

    static NewList() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    ; ---- reading -------------------------------------------------------------------------------------------------

    ; The list of the variable `name` as a copy. A variable that does not exist or is empty is a new empty list if
    ; createIfEmpty (a warning goes to the log), else an error; a variable with another content is an error.
    static Load(ctx, name, createIfEmpty := false) {
        if (ctx.GetVarType(name) = "object")
            return ctx.GetVar(name)
        value := ctx.GetVar(name, "")
        if (createIfEmpty && String(value) = "") {
            ctx.Log("f1", Lang("Warning!") " " Lang("Variable '%1%' is empty. A new list will be created.", name))
            return ListOps.NewList()
        }
        if (createIfEmpty)
            throw ElementError(Lang("Variable '%1%' is not empty and does not contain a list.", name))
        throw ElementError(Lang("Variable '%1%' does not contain a list.", name))
    }

    ; Throws ElementError(what) unless value is a list (a Map).
    static Require(value, message) {
        if (!(value is Map))
            throw ElementError(message)
        return value
    }

    ; The Integer keys of the list, ascending.
    static IntKeys(m) {
        keys := []
        for key in m {
            if (Type(key) = "Integer")
                keys.Push(key)
        }
        return keys
    }

    ; The lowest and the highest Integer key, "" if there is none (v1 MinIndex, MaxIndex).
    static MinIndex(m) {
        keys := ListOps.IntKeys(m)
        return keys.Length ? keys[1] : ""
    }

    static MaxIndex(m) {
        keys := ListOps.IntKeys(m)
        return keys.Length ? keys[keys.Length] : ""
    }

    ; The highest positive Integer key, 0 if there is none (v1 Length): the position where Push appends.
    static Length(m) {
        top := ListOps.MaxIndex(m)
        return (top = "" || top < 0) ? 0 : top
    }

    ; One of "minIndex", "maxIndex", "length", "count" (any case). count is the number of members of every kind.
    static Info(m, which) {
        switch StrLower(which) {
            case "minindex": return ListOps.MinIndex(m)
            case "maxindex": return ListOps.MaxIndex(m)
            case "length": return ListOps.Length(m)
            case "count": return m.Count
        }
        throw ElementError("Get list info: unknown information '" which "'")
    }

    ; value as the member of a Radio parameter: the text of the enum, or the enum entry at the index if the parameter
    ; holds the default index of v1 (a number from 1 to the number of choices).
    static EnumValue(value, choices) {
        if (Type(value) = "Integer" && value >= 1 && value <= choices.Length)
            return choices[value]
        return value
    }

    ; ---- comparing -----------------------------------------------------------------------------------------------

    ; The comparison of v1 `=` for two values of a list: two numbers (also texts that are numbers) are compared as
    ; numbers (1 = "1.0"), everything else as texts without regard to case. An object is never equal to anything.
    static Equal(a, b) {
        if (IsObject(a) || IsObject(b))
            return false
        if (IsNumber(a) && IsNumber(b)) {
            try
                return (a + 0) = (b + 0)
        }
        return StrCompare(String(a), String(b), "Off") = 0
    }

    ; Returned by KeyOfValue when no value equals: an object, so that it cannot be mistaken for a key (the empty text is
    ; a possible key).
    static NONE := Object()

    ; The first key (in the order of the list) whose value equals `value`, or ListOps.NONE.
    static KeyOfValue(m, value) {
        for key, item in m {
            if (ListOps.Equal(item, value))
                return key
        }
        return ListOps.NONE
    }

    static HasKey(m, key) {
        return m.Has(ListOps.NormKey(key))
    }

    ; ---- changing ------------------------------------------------------------------------------------------------

    ; Moves every Integer key >= from by delta (positive: up, negative: down). Other keys stay. The caller makes sure
    ; that nothing is in the way (an insert moves everything from `from` up by the same delta; a delete removes the
    ; key before it moves the keys above down).
    static Shift(m, from, delta) {
        moved := []
        for key, item in m {
            if (Type(key) = "Integer" && key >= from)
                moved.Push([key, item])
        }
        for pair in moved
            m.Delete(pair[1])
        for pair in moved
            m[pair[1] + delta] := pair[2]
    }

    ; Puts the values (an Array) at the positions pos, pos+1, ...; the members at pos and above move up by the number of
    ; values (insert) or are overwritten (overwrite).
    static Put(m, pos, values, overwrite := false) {
        if (!overwrite)
            ListOps.Shift(m, pos, values.Length)
        for i, item in values
            m[pos + i - 1] := item
    }

    ; Adds the values (an Array of one or more) to the list.
    ;   where   "First": at 1, 2, ... in the order given; the members from 1 up move up (v1 inserted each value at 1,
    ;           which reversed several values, M-0057)
    ;           "Last": after the highest positive key
    ;           "Specified": at `pos`. An Integer position: insert (the members at that position and above move up) or,
    ;           with method "Overwrite", assign. A position that is no Integer (a key name) is assigned, one value only.
    static Add(m, values, where, pos := "", method := "Insert") {
        switch StrLower(where) {
            case "first":
                ListOps.Put(m, 1, values)
            case "last":
                ListOps.Put(m, ListOps.Length(m) + 1, values, true)
            case "specified":
                if (!IsObject(pos) && String(pos) = "")
                    throw ElementError(Lang("Position is not specified"))
                key := ListOps.NormKey(pos)
                if (Type(key) != "Integer") {
                    if (values.Length != 1)
                        throw ElementError(Lang("Position '%1%' is not an integer value", pos))
                    m[key] := values[1]
                } else {
                    ListOps.Put(m, key, values, StrLower(method) = "overwrite")
                }
            default:
                throw ElementError("Add to list: unknown position '" where "'")
        }
    }

    ; The delimiter characters that the evaluated parameters of an element select (the four checkboxes of New list and
    ; Add to list).
    static Delimiters(p) {
        delimiters := ""
        if (p.DelimiterLinefeed)
            delimiters .= "`n"
        if (p.DelimiterComma)
            delimiters .= ","
        if (p.DelimiterSemicolon)
            delimiters .= ";"
        if (p.DelimiterSpace)
            delimiters .= " "
        return delimiters
    }

    ; The text split at the delimiter characters (an empty field stays one). Without a delimiter the whole text is one
    ; value (v1 split it into single characters, M-0057).
    static Split(text, delimiters) {
        if (text = "")
            return []
        if (delimiters = "")
            return [text]
        return StrSplit(text, StrSplit(delimiters))        ; a string is ONE delimiter; an Array of the characters is a set
    }

    ; Deletes a member and returns its value.
    ;   which   "First" (the lowest Integer key), "Last" (the highest), "Specified" (`pos`, any key)
    ;   method  "Decrement": the Integer keys above the deleted one move down by one (no gap); "KeepGap": nothing moves
    ; name is the name of the list for the error texts.
    static Delete(m, which, pos, method, name) {
        switch StrLower(which) {
            case "first", "last":
                key := (StrLower(which) = "first") ? ListOps.MinIndex(m) : ListOps.MaxIndex(m)
                if (key = "")
                    throw ElementError(Lang("The list '%1%' does not contain an integer key.", name))
            case "specified":
                if (!IsObject(pos) && String(pos) = "")
                    throw ElementError(Lang("%1% is not specified.", Lang("Position")))
                key := ListOps.NormKey(pos)
                if (!m.Has(key))
                    throw ElementError(Lang("The list '%1%' does not contain the key '%2%'.", name, pos))
            default:
                throw ElementError("Delete from list: unknown position '" which "'")
        }
        removed := m[key]
        m.Delete(key)
        if (Type(key) = "Integer" && StrLower(method) != "keepgap")
            ListOps.Shift(m, key + 1, -1)
        return removed
    }

    ; Shuffles the members with a numeric key (an Integer, or a text that is a number): their values come back with the
    ; keys 1..n in random order. Members with other keys stay. rng(lo, hi) gives an Integer from lo to hi (default:
    ; AutoHotkey Random; a test passes its own function).
    static Shuffle(m, rng := "") {
        if (!IsObject(rng))
            rng := (lo, hi) => Random(lo, hi)
        keys := []
        for key, item in m {
            if (Type(key) = "Integer" || IsNumber(key))
                keys.Push(key)
        }
        values := []
        for key in keys {
            values.Push(m[key])
            m.Delete(key)
        }
        i := values.Length
        while (i > 1) {
            j := rng(1, i)
            tmp := values[i]
            values[i] := values[j]
            values[j] := tmp
            i -= 1
        }
        for i, item in values
            m[i] := item
    }
}
