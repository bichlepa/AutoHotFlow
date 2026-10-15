#Requires AutoHotkey v2.0
; Shared parts of the Executor tests (WI-0021): test elements, a probe that records what they did, and
; helpers that build flows and an EngineOwner. Included by engine_executor.test.ahk and engine_wait.test.ahk.
#Include ..\lib\Assert.ahk
#Include EngineOwner.ahk

; Records what the test elements did. One place, reset by each test.
class Probe {
    static runs := []             ; element IDs in the order they started
    static held := Map()          ; elementId -> ctx of a Test_Hold element that waits for Release
    static stops := []            ; "elementId:x" of every Stop of a Test_Hold element
    static onRun := ""            ; called inside Test_Count.Run with the ctx

    static Reset() {
        Probe.runs := []
        Probe.held := Map()
        Probe.stops := []
        Probe.onRun := ""
    }

    static Release(elementId, result := "normal") {
        ctx := Probe.held[elementId]
        Probe.held.Delete(elementId)
        ctx.Finish(result)
    }

    static Count(elementId) {
        n := 0
        for id in Probe.runs {
            if (id = elementId)
                n += 1
        }
        return n
    }
}

; The test elements are classes of the package ExecKit (E0045): their qualified IDs are ExecKit.Test_Count and so on,
; and a flow names them with "package":"ExecKit" (El does that for "ExecKit.Test_Count").
class ExecKit {
    ; Finishes at once.
    class Test_Count extends AhfElement {
        static Mode := "inline"
        static Run(ctx, params) {
            Probe.runs.Push(ctx.elementId)
            h := Probe.onRun
            if (IsObject(h))
                h(ctx)
            ctx.Finish("normal")
        }
    }

    ; Waits until the test calls Probe.Release. Instances of the same flow share the element ID, so a
    ; second instance replaces the first entry: tests release one instance at a time.
    class Test_Hold extends AhfElement {
        static Mode := "inline"
        static Run(ctx, params) {
            Probe.runs.Push(ctx.elementId)
            Probe.held[ctx.elementId] := ctx
        }
        static Stop(ctx, params) {
            Probe.stops.Push(ctx.elementId ":" (params.HasProp("x") ? params.x : ""))
        }
    }

    ; Runs in the worker pool (FakeWorkers). A call of Run here means the engine ran a worker element itself.
    class Test_Wk extends AhfElement {
        static Mode := "worker"
        static Run(ctx, params) {
            Probe.runs.Push(ctx.elementId)
            ctx.Finish("normal")
        }
    }
}

ElementRegistry.Register(ExecKit.Test_Count)
ElementRegistry.Register(ExecKit.Test_Hold)
ElementRegistry.Register(ExecKit.Test_Wk)
Log.Configure(Log.Memory)
Ids.Configure("test")

Lines(parts*) {
    out := ""
    for i, part in parts
        out .= ((i > 1) ? "`n" : "") part
    return out
}

Trig() => '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}}'
; An action element. cls is "<package>.<class>" (the element then names its package, E0045) or a class of the package
; Default (no "package" key, as in many v1 files).
El(id, cls, pars := "{}") {
    pos := InStr(cls, ".")
    pkg := pos ? '"package":"' SubStr(cls, 1, pos - 1) '",' : ""
    return '"' id '":{"ID":"' id '","type":"action",' pkg '"class":"' SubStr(cls, pos + 1) '","pars":' pars '}'
}
Conn(id, from, to, type := "normal") => '"' id '":{"ID":"' id '","from":"' from '","to":"' to '","type":"Connection","ConnectionType":"' type '"}'

; Builds flow text: elements (array of strings) and connections (array of strings), optional policy.
FlowText(elements, connections, policy := "default", withTrigger := true) {
    els := withTrigger ? Trig() : ""
    for e in elements
        els .= (els = "" ? "" : ",") e
    cons := ""
    for c in connections
        cons .= (cons = "" ? "" : ",") c
    return '{"name":"f","flowSettings":{"ExecutionPolicy":"' policy '"},"allElements":{' els '},"allConnections":{' cons '}}'
}

; A fresh owner with the flow "f" loaded (revision 1).
NewOwner(text) {
    Probe.Reset()
    Log.memoryLines := []
    owner := EngineOwner()
    owner.flows.Load("f", text)
    return owner
}

; Replaces the definition of "f" the way a committed patch will (new revision).
Commit(owner, text) {
    rec := owner.flows.Get("f")
    rec.Commit(FlowDefinition.FromText("f", text, rec.Rev + 1))
}

HasLog(level, part) {
    for line in Log.memoryLines {
        if (line["level"] = level && InStr(line["text"], part))
            return true
    }
    return false
}
