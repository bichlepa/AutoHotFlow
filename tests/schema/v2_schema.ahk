#Requires AutoHotkey v2.0
; Writes the parameter schema of every element class that the product registers, for the comparison with v1
; (WI-0116, doc/TEST-STRATEGY.md section 8c). Run by tests/schema/test_v1_schema.py through tools/ahkrun.py, never by
; hand: the argument is the output file (JSON). Not named *.test.ahk, so the AHK runner does not collect it.
;
; Output: {"description": ..., "classes": {"<Package>.<Class>": [field, ...]}} with the fields of Parameters("") as
; plain Maps and Arrays (the Objects of the class literals are converted), or {"error": "..."} for a class whose
; Parameters("") throws. Labels are keys: no language files are read (see LangTable.Dir), so Lang() gives the key with
; spaces, as the v1 stand-in x_lang does in tools/v1_schema.py.
#SingleInstance Off
#Warn All, StdOut
#Include ..\..\src\entry\generated\Elements_engine.ahk

Log.Configure(Log.Memory)
WriteSchema()
ExitApp(0)

; Everything is in functions: a global would hide the names of the element code (#Warn All).
WriteSchema() {
    if (A_Args.Length < 1) {
        FileAppend("usage: v2_schema.ahk <output.json>`n", "*", "UTF-8")
        ExitApp(2)
    }

    ; No language files: a folder that does not exist has none (both folders are read by LangTable.Load).
    noLanguage := A_ScriptDir "\no_language_files"
    LangTable.Dir := noLanguage
    LangTable.PackagesDir := noLanguage
    LangTable.Load()

    classes := Map()
    for cls in ElementRegistry.All() {
        id := ElementRegistry.IdOf(cls)
        try {
            classes[id] := PlainValue(cls.Parameters(""))
        } catch as e {
            classes[id] := Map("error", e.Message)
        }
    }

    outPath := A_Args[1]
    if FileExist(outPath)
        FileDelete(outPath)
    text := Json.Stringify(Map("description", "Parameter schema of the v2 element classes, written by tests/schema/v2_schema.ahk. Compared with the v1 schema by tests/schema/test_v1_schema.py.", "classes", classes), 2)
    FileAppend(text "`n", outPath, "UTF-8-RAW")
    return
}

; Maps and Arrays copied; the Objects of the class literals become Maps; other values unchanged.
PlainValue(value) {
    if (value is Map) {
        out := Map()
        for key, item in value
            out[key] := PlainValue(item)
        return out
    }
    if (value is Array) {
        out := []
        for item in value
            out.Push(PlainValue(item))
        return out
    }
    if (value is Object) {
        out := Map()
        for key, item in value.OwnProps()
            out[key] := PlainValue(item)
        return out
    }
    return value
}
