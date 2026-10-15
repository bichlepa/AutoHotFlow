#Requires AutoHotkey v2.0
#SingleInstance Off

; Worker of tools/migration_report.py (WI-0045): loads flow files with the loader of the engine (FlowTable, which runs
; FlowExprConvert and the converter) and writes, per flow, the elements of unknown class and the places that carry
; MIGRATION IDs, as JSON. There is no second implementation of the conversion in Python.
;
; A_Args: 1 = result file (one JSON document), 2 = list file (one flow file path per line, UTF-8).
; Not started by hand: python tools/migration_report.py <flow file or folder> [--json]
;
; The element classes are the generated block of the engine (all classes of the product packages, WI-0047), so that
; the report sees the registry of the engine process; the test elements are not part of it. "class" in the result is
; the qualified ID "<package>.<class>" (E0045).
#Include ..\src\engine\FlowTable.ahk
#Include ..\src\entry\generated\Elements_engine.ahk

ReportOne(path) {
    flow := Map("file", path)
    SplitPath(path, , , , &id)
    try {
        text := FileRead(path, "UTF-8")
        table := FlowTable()
        table.Load(id, text)
    } catch as e {
        flow["error"] := Type(e) ": " e.Message
        return flow
    }
    def := table.Get(id).Def
    unknown := []
    places := []
    elements := def.Raw["allElements"]
    for elId, el in elements {
        qid := ElementRegistry.QualifiedId(FlowDefinition.TextOf(id, el, "package", ""), FlowDefinition.TextOf(id, el, "class", ""))
        if (def.Pending.Has(elId))
            unknown.Push(Map("element", elId, "class", qid))
        if (!el.Has(FlowDefinition.MIGRATION_KEY) || !(el[FlowDefinition.MIGRATION_KEY] is Array))
            continue
        for entry in el[FlowDefinition.MIGRATION_KEY] {
            places.Push(Map("element", elId, "class", qid
                , "par", entry["par"], "ids", entry["ids"], "v1", entry["v1"]))
        }
    }
    flow["name"] := def.Name
    flow["elements"] := elements.Count
    flow["unknownClass"] := unknown
    flow["places"] := places
    return flow
}

Main() {
    if (A_Args.Length < 2)
        throw ValueError("migration_report.ahk: result file and list file are needed")
    Log.Configure((level, source, msg, flowId) => 0)
    flows := []
    for line in StrSplit(FileRead(A_Args[2], "UTF-8"), "`n", "`r") {
        if (Trim(line) != "")
            flows.Push(ReportOne(line))
    }
    out := Map("flows", flows)
    FileAppend(Json.Stringify(out, 2), A_Args[1], "UTF-8-RAW")
}

Main()
