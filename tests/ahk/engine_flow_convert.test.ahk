#Requires AutoHotkey v2.0
; Unit tests for the conversion of expression texts when a flow is loaded (WI-39): src/engine/core/FlowExprConvert.ahk,
; the format version and the marker in FlowDefinition.ToFileText, FlowTable.Load.
#Include lib\Assert.ahk
#Include ..\..\src\engine\FlowTable.ahk
#Include ..\..\src\elements\skeleton\Action_TestExprParams.ahk
#Include ..\..\src\elements\skeleton\Trigger_Manual.ahk
#Include ..\..\src\elements\skeleton\Action_Sleep.ahk
#Include ..\..\src\elements\skeleton\Action_Do_nothing.ahk

; Test classes of a flow loader: a class without expression parameters, and one whose Parameters() fails.
class Action_TestPlainConv extends AhfElement {
    static Parameters(ctx) => [{type: "Edit", id: "Text", content: "String"}]
}
ElementRegistry.Register(Action_TestPlainConv)

class Action_TestBrokenParams extends AhfElement {
    static Parameters(ctx) {
        throw Error("Parameters needs the editor")
    }
}
ElementRegistry.Register(Action_TestBrokenParams)

Lines(parts*) {
    out := ""
    for i, p in parts
        out .= ((i > 1) ? "`n" : "") p
    return out
}

; A v1 flow: one element of the test class with a text in every parameter, one of a class that does not exist.
V1Flow(extraRoot := "") {
    return Lines(
        '{"name":"conv","category":"Tests","ElementIDCounter":"4",' extraRoot,
        '"flowSettings":{"ExecutionPolicy":"default"},',
        '"allElements":{',
        '"e1":{"ID":"e1","type":"Action","class":"Action_TestExprParams","pars":{',
        '"Expr":"x := 1.50","Num":"1.10","PosInt":"007","Either":"1.50","EitherType":"expression",',
        '"Text":"1.50 %v%","VarName":"v1.50","Raw":"1.50","Script":"a := 1.50\nb := 2","Condition":"x = 1.50 and \"a\".\"b\""}},',
        '"e2":{"ID":"e2","type":"Action","class":"Action_NotYetPorted","pars":{"Expr":"1.50","Other":"\"a\".\"b\""}},',
        '"e3":{"ID":"e3","type":"Action","class":"Action_TestPlainConv","pars":{"Text":"1.50"}}},',
        '"allConnections":{}}'
    )
}

Pars(def, id) => def.Element(id)["pars"]

CheckV1FlowIsConverted() {
    table := FlowTable()
    table.Load("f", V1Flow())
    def := table.Get("f").Def
    p := Pars(def, "e1")
    ; expression content types and V1Syntax parameters
    Assert.Equal(p["Expr"], 'x := "1.50"')
    Assert.Equal(p["Num"], '"1.10"')
    Assert.Equal(p["PosInt"], '"007"')
    Assert.Equal(p["Script"], 'a := "1.50"`nb := 2')
    Assert.Equal(p["Condition"], 'x = 1.50 and "a" . "b"')
    ; content selected by the user: "expression" is converted
    Assert.Equal(p["Either"], '"1.50"')
    ; not expressions: untouched
    Assert.Equal(p["Text"], "1.50 %v%")
    Assert.Equal(p["VarName"], "v1.50")
    Assert.Equal(p["Raw"], "1.50")
    Assert.Equal(p["EitherType"], "expression")
    ; a class without expression parameters, and an unknown class
    Assert.Equal(Pars(def, "e3")["Text"], "1.50")
    Assert.Equal(Pars(def, "e2")["Expr"], "1.50")
    Assert.Equal(Pars(def, "e2")["Other"], '"a"."b"')
    ; the unknown class waits
    Assert.Equal(def.Pending.Count, 1)
    Assert.True(def.Pending.Has("e2"))
}

CheckSelectableContentFollowsTheChoice() {
    table := FlowTable()
    text := StrReplace(V1Flow(), '"EitherType":"expression"', '"EitherType":"string"')
    table.Load("f", text)
    Assert.Equal(Pars(table.Get("f").Def, "e1")["Either"], "1.50")
    ; no choice stored: the default of the parameter (string)
    text := StrReplace(V1Flow(), '"EitherType":"expression",', "")
    table2 := FlowTable()
    table2.Load("g", text)
    Assert.Equal(Pars(table2.Get("g").Def, "e1")["Either"], "1.50")
}

CheckSavedFileCarriesFormatVersionAndMarker() {
    table := FlowTable()
    table.Load("f", V1Flow())
    def := table.Get("f").Def
    ; Raw is not changed by writing
    saved := def.ToFileText()
    Assert.True(!def.Raw.Has("formatVersion"))
    Assert.True(!def.Element("e2").Has("v1Text"))
    root := Json.Parse(saved)
    Assert.Equal(root["formatVersion"], 2)
    Assert.True(root["allElements"]["e2"]["v1Text"] == 1)
    Assert.True(!root["allElements"]["e1"].Has("v1Text"))
    Assert.True(!root["allElements"]["e3"].Has("v1Text"))
    Assert.Equal(root["allElements"]["e1"]["pars"]["Expr"], 'x := "1.50"')
}

CheckNoDoubleConversionAfterSave() {
    first := FlowTable()
    first.Load("f", V1Flow())
    saved := first.Get("f").Def.ToFileText()
    second := FlowTable()
    second.Load("f", saved)
    def := second.Get("f").Def
    ; the converted element keeps its converted text
    Assert.Equal(Pars(def, "e1")["Expr"], 'x := "1.50"')
    ; the unknown class still waits, and its v1 text is untouched
    Assert.True(def.Pending.Has("e2"))
    Assert.Equal(Pars(def, "e2")["Other"], '"a"."b"')
    ; and a third round trip changes nothing
    Assert.Equal(def.ToFileText(), saved)
}

CheckAClassThatAppearsLaterConvertsItsMarkedElements() {
    first := FlowTable()
    first.Load("f", V1Flow())
    saved := first.Get("f").Def.ToFileText()
    ; the class of e2 becomes known
    Assert.True(!ElementRegistry.classes.Has("Action_NotYetPorted"))
    ElementRegistry.Register(Action_NotYetPorted)
    try {
        second := FlowTable()
        second.Load("f", saved)
        def := second.Get("f").Def
        Assert.Equal(def.Pending.Count, 0)
        Assert.Equal(Pars(def, "e2")["Expr"], '"1.50"')
        Assert.Equal(Pars(def, "e2")["Other"], '"a" . "b"')
        ; the next save has no marker any more, and a load converts nothing again
        again := def.ToFileText()
        Assert.True(!Json.Parse(again)["allElements"]["e2"].Has("v1Text"))
        third := FlowTable()
        third.Load("f", again)
        Assert.Equal(Pars(third.Get("f").Def, "e2")["Other"], '"a" . "b"')
    } finally {
        ElementRegistry.classes.Delete("Action_NotYetPorted")
    }
}

CheckTextsOfAV2FileAreNotConvertedAgain() {
    ; a v2 file (format version, no marker): the texts are in the new syntax, even if they look like v1
    text := Lines(
        '{"name":"v2","formatVersion":2,"allElements":{',
        '"e1":{"ID":"e1","type":"Action","class":"Action_TestExprParams","pars":{"Expr":"1.50","Script":"x := 007"}}},',
        '"allConnections":{}}'
    )
    table := FlowTable()
    table.Load("f", text)
    def := table.Get("f").Def
    Assert.Equal(Pars(def, "e1")["Expr"], "1.50")
    Assert.Equal(Pars(def, "e1")["Script"], "x := 007")
    Assert.Equal(def.Pending.Count, 0)
}

CheckFailuresStayInV1Syntax() {
    ; unsupported and unreadable texts are left as they are and do not stop the load
    text := Lines(
        '{"name":"bad","allElements":{',
        '"e1":{"ID":"e1","type":"Action","class":"Action_TestExprParams","pars":{"Expr":"7 % 3","Num":"1 +","PosInt":"2"}}},',
        '"allConnections":{}}'
    )
    entries := []
    Log.Configure((level, source, msg, flowId) => entries.Push(level ": " msg))
    table := FlowTable()
    table.Load("f", text)
    Log.Configure("")
    p := Pars(table.Get("f").Def, "e1")
    Assert.Equal(p["Expr"], "7 % 3")
    Assert.Equal(p["Num"], "1 +")
    Assert.Equal(p["PosInt"], "2")
    found := 0
    for line in entries {
        if (InStr(line, "f1: ") = 1 && InStr(line, "stays in v1 syntax"))
            found += 1
    }
    Assert.Equal(found, 2)
}

CheckEveryConversionIsLogged() {
    entries := []
    Log.Configure((level, source, msg, flowId) => entries.Push(level "|" flowId "|" msg))
    table := FlowTable()
    table.Load("flow7", V1Flow())
    Log.Configure("")
    f2 := 0
    sawExpr := false
    for line in entries {
        if (InStr(line, "f2|flow7|") = 1)
            f2 += 1
        if (InStr(line, "element 'e1' parameter 'Expr': 'x := 1.50' -> 'x := ") && InStr(line, '"1.50"'))
            sawExpr := true
    }
    ; six converted parameters (Expr, Num, PosInt, Either, Script, Condition) and the summary line
    Assert.Equal(f2, 7)
    Assert.True(sawExpr, "the log names flow, element, parameter, old and new text")
}

CheckBrokenParametersDoNotStopTheLoad() {
    text := Lines(
        '{"name":"b","allElements":{',
        '"e1":{"ID":"e1","type":"Action","class":"Action_TestBrokenParams","pars":{"Expr":"1.50"}}},',
        '"allConnections":{}}'
    )
    table := FlowTable()
    table.Load("f", text)
    def := table.Get("f").Def
    Assert.Equal(Pars(def, "e1")["Expr"], "1.50")
    Assert.True(def.Pending.Has("e1"))
}

CheckMarkerSpellings() {
    for marker in ['true', '1', '"1"', '"true"'] {
        text := Lines(
            '{"name":"m","formatVersion":2,"allElements":{',
            '"e1":{"ID":"e1","type":"Action","class":"Action_TestExprParams","v1Text":' marker ',"pars":{"Expr":"1.50"}}},',
            '"allConnections":{}}'
        )
        table := FlowTable()
        table.Load("f", text)
        Assert.Equal(Pars(table.Get("f").Def, "e1")["Expr"], '"1.50"', marker)
    }
    text := Lines(
        '{"name":"m","formatVersion":2,"allElements":{',
        '"e1":{"ID":"e1","type":"Action","class":"Action_TestExprParams","v1Text":false,"pars":{"Expr":"1.50"}}},',
        '"allConnections":{}}'
    )
    table := FlowTable()
    table.Load("f", text)
    Assert.Equal(Pars(table.Get("f").Def, "e1")["Expr"], "1.50")
}

CheckFlowsWithoutExpressionsKeepTheirDefinition() {
    ; a flow of the walking skeleton: nothing to convert, Raw stays what the file said
    text := FileRead(A_ScriptDir "\..\data\skeleton_flow.json", "UTF-8")
    table := FlowTable()
    table.Load("s", text)
    def := table.Get("s").Def
    Assert.Equal(def.Pending.Count, 0)
    Assert.True(!def.Raw.Has("formatVersion"))
    Assert.Equal(Json.Stringify(def.Raw), Json.Stringify(Json.Parse(text)))
}

class Action_NotYetPorted extends AhfElement {
    static Parameters(ctx) => [{type: "Edit", id: "Expr", content: "Expression"}, {type: "Edit", id: "Other", content: "Expression"}]
}

TestRun.Init()

TestRun.Case("a v1 flow: expression parameters and V1Syntax are converted, the rest stays", CheckV1FlowIsConverted)
TestRun.Case("selectable content type follows the stored choice", CheckSelectableContentFollowsTheChoice)
TestRun.Case("a saved file has the format version and the marker of waiting elements", CheckSavedFileCarriesFormatVersionAndMarker)
TestRun.Case("no double conversion after a save, unknown class keeps text and marker", CheckNoDoubleConversionAfterSave)
TestRun.Case("a class that appears later converts its marked elements once", CheckAClassThatAppearsLaterConvertsItsMarkedElements)
TestRun.Case("the texts of a v2 file are not converted", CheckTextsOfAV2FileAreNotConvertedAgain)
TestRun.Case("unsupported and unreadable texts stay and are logged", CheckFailuresStayInV1Syntax)
TestRun.Case("every conversion is in the log", CheckEveryConversionIsLogged)
TestRun.Case("Parameters() that fails keeps the element waiting", CheckBrokenParametersDoNotStopTheLoad)
TestRun.Case("spellings of the marker", CheckMarkerSpellings)
TestRun.Case("a flow without expressions keeps its definition", CheckFlowsWithoutExpressionsKeepTheirDefinition)

TestRun.Finish()
