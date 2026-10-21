#Requires AutoHotkey v2.0
; Unit tests for the copy of the variables at an unhandled exception (WI-0113, REQ-USE-080 part 2, PROTOCOL 4.7a):
; src/engine/core/ErrorSnapshot.ahk (the scopes, the hidden tables left out, JSON of objects, the bounds of a copy) and
; src/engine/core/FlowErrors.ahk (the last five errors per flow, the flow ID without case, Forget). The flow-level
; behaviour (the notice, cmd.flow.error.get, a deleted flow) is tests/integration/test_error_window.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\Instance.ahk
#Include ..\..\src\engine\core\ErrorSnapshot.ahk
#Include ..\..\src\engine\core\FlowErrors.ahk

Ids.Configure("test")

; A branch with one variable of each scope, and a hidden value that must not be copied.
BranchOf(&inst, &thr) {
    inst := Instance("i1", "f1")
    thr := ThreadState("t1", "i1", "E1")
    thr.Loops.Visible["A_Index"] := 3
    thr.Vars["A_TriggerTime"] := "20260101000000"
    inst.Vars["x"] := 5
    inst.HiddenVars["secret"] := "p"
    thr.HiddenVars["hidden"] := "q"
}

TestRun.Case("The copy holds the loop, thread and instance variables and no hidden value", () => CopyHasTheScopes())
CopyHasTheScopes() {
    BranchOf(&inst, &thr)
    snap := ErrorSnapshot.Take(inst, thr)
    Assert.Equal(snap["omitted"], 0)
    found := Map()
    for v in snap["vars"]
        found[v["scope"] "." v["name"]] := v["value"]
    Assert.Equal(found.Count, 3, "three variables, the hidden ones are not in the copy")
    Assert.Equal(found["loop.A_Index"], "3")
    Assert.Equal(found["thread.A_TriggerTime"], "20260101000000")
    Assert.Equal(found["instance.x"], "5")
}

TestRun.Case("An object is copied as its JSON text, a list as an array", () => ObjectsAreJson())
ObjectsAreJson() {
    BranchOf(&inst, &thr)
    list := VarValues.NewMap()
    list[1] := "a"
    list[2] := "b"
    inst.Vars["list"] := list
    snap := ErrorSnapshot.Take(inst, thr)
    for v in snap["vars"] {
        if (v["name"] = "list")
            Assert.Equal(v["value"], '["a","b"]')
    }
}

TestRun.Case("The copy does not follow later changes of the variables", () => CopyIsIndependent())
CopyIsIndependent() {
    BranchOf(&inst, &thr)
    snap := ErrorSnapshot.Take(inst, thr)
    inst.Vars["x"] := 99
    for v in snap["vars"] {
        if (v["name"] = "x")
            Assert.Equal(v["value"], "5", "the copy keeps the value of the error")
    }
}

TestRun.Case("At most 200 variables are copied, the rest is counted as omitted", () => VariableCountIsBounded())
VariableCountIsBounded() {
    inst := Instance("i1", "f1")
    thr := ThreadState("t1", "i1", "E1")
    loop 250
        inst.Vars["v" A_Index] := A_Index
    snap := ErrorSnapshot.Take(inst, thr)
    Assert.Equal(snap["vars"].Length, ErrorSnapshot.MAX_VARS)
    Assert.Equal(snap["omitted"], 50)
}

TestRun.Case("The copy holds at most 64 KB of names and values", () => ByteCountIsBounded())
ByteCountIsBounded() {
    inst := Instance("i1", "f1")
    thr := ThreadState("t1", "i1", "E1")
    long := ""
    loop 1500
        long .= "x"
    loop 100
        inst.Vars["v" A_Index] := long     ; each value is cut to 1000 characters: about 1 KB per variable
    snap := ErrorSnapshot.Take(inst, thr)
    total := 0
    for v in snap["vars"]
        total += StrLen(v["name"]) + StrLen(v["value"])
    Assert.Equal(snap["vars"].Length + snap["omitted"], 100, "every variable is either copied or counted")
    Assert.Equal(snap["omitted"] > 0, true, "the 100 KB do not fit into 64 KB")
    Assert.Equal(total <= ErrorSnapshot.MAX_BYTES, true, "the copied names and values stay within 64 KB")
}

TestRun.Case("A value longer than 1000 characters is cut and ends with three dots", () => ValueIsCut())
ValueIsCut() {
    inst := Instance("i1", "f1")
    thr := ThreadState("t1", "i1", "E1")
    long := ""
    loop 1500
        long .= "y"
    inst.Vars["long"] := long
    snap := ErrorSnapshot.Take(inst, thr)
    text := snap["vars"][1]["value"]
    Assert.Equal(StrLen(text), ErrorSnapshot.MAX_VALUE_CHARS + 3)
    Assert.Equal(SubStr(text, -3), "...")
}

TestRun.Case("A flow keeps its last five errors, each with its own ID", () => KeepsTheLastFive())
KeepsTheLastFive() {
    errors := FlowErrors()
    idList := []
    loop 6
        idList.Push(errors.Add("f1", Map("message", "m" A_Index)))
    Assert.Equal(errors.Count("f1"), FlowErrors.KEEP)
    Assert.Equal(errors.Get("f1", idList[1]), "", "the oldest error is gone")
    Assert.Equal(errors.Get("f1", idList[2])["message"], "m2", "the second one is still kept")
    Assert.Equal(errors.Get("f1", idList[6])["message"], "m6")
    Assert.Equal(errors.Get("f1", idList[6])["errorId"], idList[6], "the entry knows its ID")
    Assert.Equal(errors.Get("f2", idList[6]), "", "an error belongs to its flow")
}

TestRun.Case("The flow ID is matched without case, and Forget drops the flow's errors", () => ForgetAndCase())
ForgetAndCase() {
    errors := FlowErrors()
    id := errors.Add("Flow", Map("message", "m"))
    Assert.Equal(errors.Get("flow", id)["message"], "m", "the flow ID ignores case")
    errors.Forget("flow")
    Assert.Equal(errors.Get("Flow", id), "", "forgotten with the flow")
    Assert.Equal(errors.Count("Flow"), 0)
    errors.Forget("never-there")         ; no error for an unknown flow
}

TestRun.Finish()
