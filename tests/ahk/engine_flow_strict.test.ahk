#Requires AutoHotkey v2.0
; Unit tests for the flow option strictTypes (WI-0042, E0034): FlowDefinition.StrictTypes and the key that ToFileText
; writes. What the mode does to an evaluation is tested in element_evalparams.test.ahk.
#Include lib\Assert.ahk
#Include ..\..\src\engine\FlowTable.ahk

FlowText(settings := '{"ExecutionPolicy":"default"}', extraRoot := "") {
    return '{"name":"s",' extraRoot '"flowSettings":' settings ',"allElements":{},"allConnections":{}}'
}

Loaded(text) {
    table := FlowTable()
    table.Load("s", text)
    return table.Get("s").Def
}

CheckAV1FlowIsInCompatibilityMode() {
    def := Loaded(FlowText())
    Assert.Equal(def.StrictTypes, 0)
    ; the definition in memory is the file: the key is not added to Raw
    Assert.True(!def.Raw["flowSettings"].Has("strictTypes"))
}

CheckAV2FileWithoutTheKeyIsInCompatibilityMode() {
    def := Loaded(FlowText(, '"formatVersion":2,'))
    Assert.Equal(def.StrictTypes, 0)
}

CheckTheKeyDecides() {
    for spelling in ["true", "1", '"1"', '"true"', '"TRUE"']
        Assert.Equal(Loaded(FlowText('{"strictTypes":' spelling '}')).StrictTypes, 1, spelling)
    for spelling in ["false", "0", '"0"', '"false"', '""', '"yes"', "[]"]
        Assert.Equal(Loaded(FlowText('{"strictTypes":' spelling '}')).StrictTypes, 0, spelling)
}

CheckASaveWritesTheMode() {
    root := Json.Parse(Loaded(FlowText()).ToFileText())
    Assert.True(root["flowSettings"]["strictTypes"] == 0, "false after a load of a v1 file")
    Assert.Equal(root["flowSettings"]["ExecutionPolicy"], "default")
    Assert.True(InStr(Loaded(FlowText()).ToFileText(), '"strictTypes": false'), "written as a JSON boolean")
    strict := Loaded(FlowText('{"strictTypes":true}'))
    text := strict.ToFileText()
    Assert.True(InStr(text, '"strictTypes": true'), text)
    ; loading what was saved keeps the mode, and saving again gives the same text
    again := Loaded(text)
    Assert.Equal(again.StrictTypes, 1)
    Assert.Equal(again.ToFileText(), text)
}

CheckAFlowWithoutSettings() {
    def := Loaded('{"name":"s","allElements":{},"allConnections":{}}')
    Assert.Equal(def.StrictTypes, 0)
    root := Json.Parse(def.ToFileText())
    Assert.True(root["flowSettings"]["strictTypes"] == 0)
    Assert.True(!def.Raw.Has("flowSettings"), "Raw is not changed by writing")
}

CheckNewFlowsAreStrict() {
    Assert.Equal(FlowDefinition.NEW_FLOW_STRICT_TYPES, 1)
}

TestRun.Init()

TestRun.Case("a v1 flow is in compatibility mode; Raw is not changed", CheckAV1FlowIsInCompatibilityMode)
TestRun.Case("a v2 file without strictTypes is in compatibility mode (migrated)", CheckAV2FileWithoutTheKeyIsInCompatibilityMode)
TestRun.Case("flowSettings.strictTypes decides; spellings", CheckTheKeyDecides)
TestRun.Case("a save writes the mode as a JSON boolean, a round trip keeps it", CheckASaveWritesTheMode)
TestRun.Case("a flow without flowSettings gets them when saved", CheckAFlowWithoutSettings)
TestRun.Case("a flow that v2 creates is strict", CheckNewFlowsAreStrict)

TestRun.Finish()
