#Requires AutoHotkey v2.0
; Unit tests for the variable model of the engine (WI-0040, src/engine/vars, doc/EXPRESSION-LANGUAGE.md section 18):
; location by name, built-in variables, values and paths, %var% substitution, the resolver of the evaluator,
; lists, imports of a worker, hidden variables, the common place, loop variables on the loop stack.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\expr\Expr.ahk
#Include ..\..\src\engine\core\Instance.ahk
#Include ..\..\src\engine\vars\VarAccess.ahk

; A fresh set of tables and an access object. common: the place without instance and thread.
class Fx {
    __New(common := false) {
        this.store := EngineVars()
        this.inst := Instance("inst1", "flow1")
        this.thread := ThreadState("thr1", "inst1", "el1")
        this.logs := []
        logFn := ObjBindMethod(this, "_Log")
        env := Map("flowId", "flow1", "elementId", "el1", "flowName", "My flow", "elementName", "My element"
            , "workingDir", "C:\work")
        this.access := common ? VarAccess(this.store, "", "", env, logFn) : VarAccess(this.store, this.inst, this.thread, env, logFn)
    }

    _Log(level, text) {
        this.logs.Push(level ": " text)
    }

    LastLog() => this.logs.Length ? this.logs[this.logs.Length] : ""
}

NewMap(pairs*) {
    m := VarValues.NewMap()
    loop pairs.Length // 2
        m[pairs[2 * A_Index - 1]] := pairs[2 * A_Index]
    return m
}

Keys(m) {
    out := ""
    for k in m
        out .= (out = "" ? "" : ",") k
    return out
}

; ---- names ----------------------------------------------------------------------------------------------------

CheckDestination() {
    cases := [
        ["x", "", false, "instance"],
        ["global_x", "", false, "global"],
        ["GLOBAL_x", "", false, "global"],
        ["static_x", "", false, "static"],
        ["A_x", "", false, "error_noPermission"],
        ["A_x", "thread", false, "thread"],
        ["a_x", "Thread", false, "thread"],
        ["A_x", "LOOP", false, "loop"],
        ["A_x", "instance", false, "error_noPermission"],
        ["x", "thread", false, "error_NotStartWith_A"],
        ["global_x", "loop", false, "error_NotStartWith_A"],
        ["globalx", "", false, "instance"],
        ["", "", false, "instance"],
        ["x", "", true, "error_noPermission"],
        ["A_x", "thread", true, "error_noPermission"],
        ["global_x", "", true, "global"],
        ["static_x", "thread", true, "static"],
    ]
    for c in cases
        Assert.Equal(VarNames.Destination(c[1], c[2], c[3]), c[4], c[1] " / " c[2] " / common " c[3])
}

CheckNameRule() {
    Assert.Equal(VarNames.Check("abc"), "OK")
    Assert.Equal(VarNames.Check(""), "Empty")
    Assert.Equal(VarNames.Check("1abc"), "StartsWithNumber")
    Assert.Equal(VarNames.Check("a.b"), "ForbiddenCharacter")
    Assert.Equal(VarNames.Check("a b"), "ForbiddenCharacter")
    Assert.Equal(VarNames.Check("ä#@$"), "OK")
}

; ---- location -------------------------------------------------------------------------------------------------

CheckLocationByName() {
    f := Fx()
    a := f.access
    f.thread.Loops.Visible["A_Index"] := 2
    f.thread.Vars["A_Index"] := 9
    f.thread.Vars["A_Foo"] := "t"
    f.inst.Vars["x"] := "i"
    f.store.Global["global_g"] := "g"
    f.store.Static("flow1")["static_s"] := "s"
    f.store.Static("other")["static_o"] := "o"
    Assert.Equal(a.Location("A_Index"), "loop", "loop before thread")
    Assert.Equal(a.GetVar("a_index"), 2)
    Assert.Equal(a.Location("A_Foo"), "thread")
    Assert.Equal(a.Location("A_Space"), "builtin")
    Assert.Equal(a.Location("A_Nothing"), "")
    Assert.Equal(a.Location("x"), "instance")
    Assert.Equal(a.Location("X"), "instance", "names ignore case")
    Assert.Equal(a.Location("global_g"), "global")
    Assert.Equal(a.Location("static_s"), "static")
    Assert.Equal(a.Location("static_o"), "", "static of another flow")
    Assert.Equal(a.Location("y"), "")
    f.thread.Loops.Visible.Delete("A_Index")
    Assert.Equal(a.GetVar("A_Index"), 9, "the thread variable is visible again")
}

CheckNameDecidesTheTable() {
    f := Fx()
    ; a variable that sits in the wrong table is not found: the name says where to look (v1)
    f.inst.Vars["global_x"] := 1
    f.inst.Vars["A_x"] := 1
    f.thread.Vars["y"] := 1
    Assert.Equal(f.access.Location("global_x"), "")
    Assert.Equal(f.access.Location("A_x"), "")
    Assert.Equal(f.access.Location("y"), "")
}

CheckHiddenVariables() {
    f := Fx()
    a := f.access
    Assert.Equal(a.SetVar("list", "hidden", "", true), 1)
    Assert.Equal(a.SetVar("A_Pos", 3, "loop", true), 1)
    Assert.Equal(a.SetVar("A_Mark", 1, "thread", true), 1)
    Assert.Equal(a.GetVar("list", "none"), "none", "not visible")
    Assert.Equal(a.GetVar("list", "", true), "hidden")
    Assert.Equal(a.Location("A_Pos", true), "loop")
    Assert.Equal(a.Location("A_Mark", true), "thread")
    Assert.Equal(f.inst.HiddenVars["list"], "hidden")
    Assert.Equal(a.ListVars().Length, 0, "hidden variables are not listed")
    Assert.Throws(() => a.SetVar("global_x", 1, "", true), ElementError)
    Assert.Equal(a.DeleteVar("list", true), 1)
    Assert.Equal(a.HasVar("list", true), 0)
}

CheckCommonPlace() {
    f := Fx(true)
    a := f.access
    f.inst.Vars["x"] := "inst"
    f.store.Global["global_g"] := "g"
    Assert.Equal(a.HasVar("x"), 0, "no instance in common")
    Assert.Equal(a.GetVar("global_g"), "g")
    Assert.Equal(a.GetVar("A_Space"), " ")
    Assert.Equal(a.SetVar("x", 1), 0)
    Assert.Equal(f.LastLog(), "f0: Setting variable 'x' failed. No permission.")
    Assert.Equal(a.SetVar("A_x", 1, "thread"), 0)
    Assert.Equal(a.SetVar("static_s", 1), 1)
    Assert.Equal(f.store.Static("flow1")["static_s"], 1)
    Assert.Equal(Keys(NewMapOfList(a.ListVars())), "global_g,static_s")
    Assert.Equal(a.Replace("%x%|%global_g%"), "|g")
    Assert.Equal(f.LastLog(), "f0: Retrieving variable 'x' failed. It does not exist or is neither global nor static")
}

NewMapOfList(list) {
    m := VarValues.NewMap()
    for v in list
        m[v] := 1
    return m
}

; ---- setting ----------------------------------------------------------------------------------------------------

CheckSetVarRules() {
    f := Fx()
    a := f.access
    Assert.Equal(a.SetVar("x", 5), 1)
    Assert.Equal(f.inst.Vars["x"], 5, "a number stays a number")
    Assert.Equal(a.SetVar("A_Foo", "t", "thread"), 1)
    Assert.Equal(f.thread.Vars["A_Foo"], "t")
    Assert.Equal(a.SetVar("A_Index", 1, "loop"), 1)
    Assert.Equal(f.thread.Loops.Visible["A_Index"], 1)
    Assert.Equal(a.SetVar("global_g", "g"), 1)
    Assert.Equal(f.store.Global["global_g"], "g")
    Assert.Equal(a.SetVar("static_s", "s"), 1)
    Assert.Equal(f.store.Static("flow1")["static_s"], "s")
    Assert.Equal(a.SetVar("1x", "v"), 1, "v1 Var_Set accepts a leading digit")
    errors := [
        ["", "", "f0: Setting a variable failed. Its name is empty."],
        ["a.b", "", "f0: Setting variable 'a.b' failed. It contains forbidden characters."],
        ["a b", "", "f0: Setting variable 'a b' failed. It contains forbidden characters."],
        ["A_Foo", "", "f0: Setting variable 'A_Foo' failed. No permission."],
        ["A_Foo", "instance", "f0: Setting variable 'A_Foo' failed. No permission."],
        ["x", "thread", "f0: Setting variable 'x' failed. It does not start with 'A_'."],
    ]
    for e in errors {
        Assert.Equal(a.SetVar(e[1], "v", e[2]), 0, e[1])
        Assert.Equal(f.LastLog(), e[3])
    }
}

CheckValuesAreCopies() {
    f := Fx()
    a := f.access
    original := NewMap("k", "v")
    a.SetVar("o", original)
    original["k"] := "changed"
    Assert.Equal(f.inst.Vars["o"]["k"], "v", "the variable has its own copy")
    got := a.GetVar("o")
    got["k"] := "changed"
    Assert.Equal(f.inst.Vars["o"]["k"], "v", "a read gives a copy")
    a.SetVar("l", [10, "b", [1]])
    l := f.inst.Vars["l"]
    Assert.True(l is Map, "an Array becomes a Map")
    Assert.Equal(Keys(l), "1,2,3")
    Assert.Equal(l[3][1], 1)
    Assert.Equal(a.VarType("l"), "object")
    Assert.Equal(a.VarType("o.k"), "normal")
    Assert.Equal(a.VarType("none"), "")
}

; ---- objects and paths --------------------------------------------------------------------------------------------

CheckKeysAndOrder() {
    m := VarValues.Import(NewMap("b", 1, "10", 2, "2", 3, "A", 4, "01", 5, "-3", 6, "x1", 7))
    Assert.Equal(Keys(m), "-3,1,2,10,A,b,x1", "Integer keys ascending, then texts without case")
    Assert.Equal(m[1], 5, "01 is the key 1")
    Assert.Equal(VarValues.NormKey("007"), 7)
    Assert.Equal(VarValues.NormKey("1.5"), "1.5")
    Assert.Equal(VarValues.NormKey(" 1"), " 1", "spaces make a text")
    Assert.Equal(VarValues.NormKey("1234567890123456789"), "1234567890123456789", "too long for an Integer")
    Assert.True(VarValues.IsList(VarValues.Import([1, 2])))
    Assert.Equal(VarValues.IsList(NewMap(1, "a", 3, "b")), false)
}

CheckPaths() {
    f := Fx()
    a := f.access
    a.SetVar("list", ["p", "q"])
    a.SetVar("o", NewMap("a", NewMap("b", "deep")))
    Assert.Equal(a.GetVar("list.1"), "p")
    Assert.Equal(a.GetVar("list.2"), "q")
    Assert.Equal(a.GetVar("list.3", "none"), "none")
    Assert.Equal(a.GetVar("o.A.B"), "deep", "keys ignore case")
    Assert.Equal(a.GetVar("o.a.b.c", "none"), "none", "a member of a text")
    Assert.Equal(a.Location("o.a"), "instance")
    ; a Map that did not come through Import (object() in an expression) may hold "1" as a text
    f.inst.Vars["m"] := NewMap("1", "text key")
    Assert.Equal(a.GetVar("m.1"), "text key")
    Assert.Equal(a.DeleteVar("o.a.b"), 1)
    Assert.Equal(a.HasVar("o.a.b"), 0)
    Assert.Equal(a.HasVar("o.a"), 1)
    Assert.Equal(a.DeleteVar("A_Space"), 0, "built-in variables cannot be deleted")
}

CheckGlobalAndStaticPaths() {
    f := Fx()
    f.store.Global["global_o"] := VarValues.Import(NewMap("k", "v"))
    Assert.Equal(f.access.GetVar("global_o.k"), "v", "v1 could not read this (it looked for a file)")
}

; ---- resolver of the evaluator -----------------------------------------------------------------------------------

Eval(f, text, kind := "expression") => Expr.Evaluate(text, f.access, (level, msg) => f.logs.Push(level ": " msg), kind)

CheckResolver() {
    f := Fx()
    f.inst.Vars["x"] := 5
    f.thread.Loops.Visible["A_Index"] := 3
    f.store.Global["global_g"] := 2
    Assert.Equal(Eval(f, "x * A_Index + global_g")["value"], 17)
    res := Eval(f, "a_flowName . '/' . A_ElementName")
    Assert.Equal(res["value"], "My flow/My element")
    res := Eval(f, "y := x + 1`nglobal_h := 7`nstatic_k := 8", "script")
    Assert.Equal(f.inst.Vars["y"], 6)
    Assert.Equal(f.store.Global["global_h"], 7)
    Assert.Equal(f.store.Static("flow1")["static_k"], 8)
    res := Eval(f, "missing + 1")
    Assert.Equal(res["missing"][1]["name"], "missing")
}

CheckResolverPaths() {
    f := Fx()
    res := Eval(f, "o.a.b := 1`nl := object()`nl[1] := 'x'`nl['2'] := 'y'`nv := l.1 . l[2]", "script")
    Assert.Equal(res["errors"].Length, 0, "no errors")
    Assert.Equal(f.inst.Vars["o"]["a"]["b"], 1, "the members on the way are created")
    Assert.Equal(Keys(f.inst.Vars["l"]), "1,2", "'2' is the key 2")
    Assert.Equal(f.inst.Vars["v"], "xy")
    f.inst.Vars["t"] := "text"
    res := Eval(f, "t.k := 1")
    Assert.Equal(res["errors"].Length, 1)
    Assert.True(InStr(res["errors"][1]["message"], "'t' is not an object"), res["errors"][1]["message"])
    Assert.Equal(f.inst.Vars["t"], "text")
    f.store.Global["global_o"] := VarValues.NewMap()
    Eval(f, "global_o.n := 5")
    Assert.Equal(f.store.Global["global_o"]["n"], 5)
}

CheckResolverRefusesAnAName() {
    f := Fx()
    res := Eval(f, "A_Index := 5")
    Assert.Equal(res["errors"].Length, 1)
    Assert.Equal(res["errors"][1]["message"], "Setting variable 'A_Index' failed. No permission.")
    Assert.Equal(f.thread.Vars.Count + f.thread.Loops.Visible.Count + f.inst.Vars.Count, 0)
}

CheckAssignmentCopies() {
    f := Fx()
    Eval(f, "a := object('k', 1)`nb := a`nb.k := 2", "script")
    Assert.Equal(f.inst.Vars["a"]["k"], 1, "b is a copy of a")
    Assert.Equal(f.inst.Vars["b"]["k"], 2)
}

; ---- built-in variables ----------------------------------------------------------------------------------------

CheckBuiltIns() {
    f := Fx()
    a := f.access
    Assert.Equal(BuiltInVars.Names().Length, 68, "55 of AutoHotkey and 13 of AutoHotFlow")
    Assert.Equal(a.GetVar("A_Space"), " ")
    Assert.Equal(a.GetVar("a_lf"), "`n")
    Assert.Equal(a.GetVar("A_LineFeed"), "`n")
    Assert.Equal(a.GetVar("A_CR"), "`r")
    Assert.Equal(a.GetVar("A_PtrSize"), 8)
    Assert.Equal(a.GetVar("a_flowid"), "flow1")
    Assert.Equal(a.GetVar("A_FlowName"), "My flow")
    Assert.Equal(a.GetVar("A_ElementID"), "el1")
    Assert.Equal(a.GetVar("A_WorkingDir"), "C:\work")
    Assert.Equal(a.GetVar("A_AhfVersion"), AhfVersion.Current)
    Assert.Equal(StrLen(a.GetVar("A_YWeek")), 2, "only the week")
    Assert.Equal(StrLen(a.GetVar("A_Now")), 14)
    Assert.True(a.GetVar("A_NowString") != "")
    Assert.Equal(a.HasVar("a_vt"), 0, "in neither name list of v1")
    Assert.Equal(a.HasVar("A_Space.x"), 0, "a built-in variable has no members")
    Assert.Equal(a.SetVar("A_Space", "x", "thread"), 1, "a thread variable may have the name of a built-in")
    Assert.Equal(a.GetVar("A_Space"), "x", "and hides it")
}

CheckWorkingDir() {
    dflt := A_MyDocuments "\AutoHotFlow"
    Assert.Equal(BuiltInVars.WorkingDirOf(""), dflt)
    Assert.Equal(BuiltInVars.WorkingDirOf(NewMap("DefaultWorkingDir", 1, "WorkingDir", "D:\x")), dflt)
    Assert.Equal(BuiltInVars.WorkingDirOf(NewMap("DefaultWorkingDir", "0", "WorkingDir", "D:\x")), "D:\x")
    Assert.Equal(BuiltInVars.WorkingDirOf(NewMap("DefaultWorkingDir", 0, "WorkingDir", "")), dflt)
    Assert.Equal(BuiltInVars.WorkingDirOf(NewMap("WorkingDir", "D:\y")), "D:\y")
    ; the global setting (WI-0077) replaces the built-in default, the own folder of a flow still wins
    Assert.Equal(BuiltInVars.WorkingDirOf("", "E:\global"), "E:\global")
    Assert.Equal(BuiltInVars.WorkingDirOf(NewMap("DefaultWorkingDir", 1, "WorkingDir", "D:\x"), "E:\global"), "E:\global")
    Assert.Equal(BuiltInVars.WorkingDirOf(NewMap("DefaultWorkingDir", 0, "WorkingDir", "D:\x"), "E:\global"), "D:\x")
}

; ---- substitution -------------------------------------------------------------------------------------------------

CheckReplace() {
    f := Fx()
    a := f.access
    f.inst.Vars["x"] := "X"
    f.inst.Vars["n"] := 0.5
    f.inst.Vars["v"] := "%x%"
    f.inst.Vars["o"] := VarValues.Import(NewMap("k", "v", "n", 1))
    f.thread.Vars["A_Foo"] := "T"
    cases := [
        ["abc", "abc"],
        ["%x%", "X"],
        ["a%x%b%X%c", "aXbXc"],
        ["n=%n%", "n=0.5"],
        ["%v%", "%x%", "a value is not replaced again"],
        ["100%", "100%"],
        ["%%", "%%"],
        ["%%%", ""],
        ["50% off %x%", "50x%", "v1 takes the first pair of percent signs"],
        ["%o.k%", "v"],
        ["%o%", "", "an object is the empty text"],
        ["%A_Foo%%A_Space%", "T "],
        ["a`n%x%`nb", "a`nX`nb"],
    ]
    for c in cases
        Assert.Equal(a.Replace(c[1]), c[2], (c.Length > 2) ? c[3] : c[1])
    missing := []
    Assert.Equal(a.Replace("[%nothing%]", false, missing), "[]")
    Assert.Equal(missing[1], "nothing")
    Assert.Equal(f.LastLog(), "f0: Retrieving variable 'nothing' failed. It does not exist")
    Assert.Equal(a.Replace("%o%", true), '{`n  "k": "v",`n  "n": 1`n}', "ConvertObjectToString")
}

CheckJsonText() {
    Assert.Equal(VarJson.Stringify(VarValues.Import([1, "two"])), '[1,"two"]')
    Assert.Equal(VarJson.Stringify(VarValues.Import([1, "two"]), 2), '[`n  1,`n  "two"`n]')
    Assert.Equal(VarJson.Stringify(VarValues.NewMap()), "{}")
    Assert.Equal(VarJson.Stringify(VarValues.Import(NewMap("b", 0.5, "a", "x/y", "1", "one"))), '{"1":"one","a":"x/y","b":0.5}')
    Assert.Equal(VarJson.Stringify(VarValues.Import(NewMap("a", NewMap("b", [1, 2]))), 2)
        , '{`n  "a": {`n    "b": [`n      1,`n      2`n    ]`n  }`n}')
}

; ---- lists, imports ------------------------------------------------------------------------------------------------

CheckListVars() {
    f := Fx()
    a := f.access
    f.thread.Loops.Visible["A_Index"] := 1
    f.thread.Vars["A_Foo"] := 1
    f.inst.Vars["x"] := 1
    f.store.Static("flow1")["static_s"] := 1
    f.store.Global["global_g"] := 1
    f.inst.HiddenVars["h"] := 1
    all := a.ListVars()
    text := ""
    for name in all
        text .= (text = "" ? "" : ",") name
    Assert.Equal(text, "A_Index,A_Foo,x,static_s,global_g", "loop, thread, instance, static, global")
    Assert.Equal(a.ListVars("instance")[1], "x")
    Assert.Equal(a.ListVars("GLOBAL")[1], "global_g")
    Assert.Throws(() => a.ListVars("nowhere"), ValueError)
}

; ---- loop stack and threads ----------------------------------------------------------------------------------------

CheckLoopStackKeepsOuterLoopVariables() {
    f := Fx()
    a := f.access
    loops := f.thread.Loops
    loops.Push()                                   ; enter the outer loop
    a.SetVar("A_Index", 1, "loop")
    a.SetVar("A_List", "outer", "loop", true)
    loops.Push()                                   ; enter the inner loop: the outer values are kept on the stack
    a.SetVar("A_Index", 7, "loop")
    a.SetVar("A_List", "inner", "loop", true)
    Assert.Equal(a.GetVar("A_Index"), 7)
    loops.Pop()                                    ; leave the inner loop
    Assert.Equal(a.GetVar("A_Index"), 1, "the outer loop variable is back")
    Assert.Equal(a.GetVar("A_List", "", true), "outer", "and the hidden one")
    loops.Pop()                                    ; leave the outer loop
    Assert.Equal(a.HasVar("A_Index"), 0, "nothing outside the loops")
}

; F-0097: entering a loop does not copy the snapshot of the outer list loop. The snapshot is one Map of n members;
; a copy per entry made a loop inside a list loop cost O(n) per entry. Leaving the loop restores the very object.
CheckLoopStackSharesTheSnapshot() {
    f := Fx()
    a := f.access
    loops := f.thread.Loops
    items := []
    loop 2000
        items.Push("item" A_Index)
    loops.Push()                                   ; enter the outer list loop
    a.SetVar("A_LoopCurrentList", items, "loop", true)
    snapshot := loops.Hidden["A_LoopCurrentList"]    ; the object itself: GetVar returns a copy
    loops.Push()                                   ; enter the inner loop
    a.SetVar("A_Index", 1, "loop")
    Assert.Equal(ObjPtr(loops.Hidden["A_LoopCurrentList"]), ObjPtr(snapshot), "the inner loop sees the same snapshot")
    seen := a.GetVar("A_LoopCurrentList", "", true)
    Assert.Equal(seen.Count, 2000, "the inner loop sees all members")
    Assert.Equal(seen[2000], "item2000")
    loops.Pop()                                    ; leave the inner loop
    Assert.Equal(ObjPtr(loops.Hidden["A_LoopCurrentList"]), ObjPtr(snapshot), "no copy on entry: the same object is restored")
    loops.Pop()
}

; F-0097: the inner loop sets its own snapshot; the outer one comes back with its values, and the inner loop
; does not see the outer values.
CheckNestedSnapshotsStayApart() {
    f := Fx()
    a := f.access
    loops := f.thread.Loops
    loops.Push()
    a.SetVar("A_LoopCurrentList", ["o1", "o2"], "loop", true)
    a.SetVar("A_Index", 1, "loop")
    loops.Push()
    a.SetVar("A_LoopCurrentList", ["i1"], "loop", true)
    a.SetVar("A_Index", 5, "loop")
    inner := a.GetVar("A_LoopCurrentList", "", true)
    Assert.Equal(inner.Count, 1, "the inner loop has its own snapshot")
    Assert.Equal(inner[1], "i1")
    Assert.Equal(a.GetVar("A_Index"), 5)
    loops.Pop()
    outer := a.GetVar("A_LoopCurrentList", "", true)
    Assert.Equal(outer.Count, 2, "the outer snapshot is back")
    Assert.Equal(outer[1], "o1")
    Assert.Equal(outer[2], "o2")
    Assert.Equal(a.GetVar("A_Index"), 1, "and the outer index")
    loops.Pop()
    Assert.Equal(a.HasVar("A_LoopCurrentList", true), 0, "nothing outside the loops")
}

CheckThreadCloneCopiesVariables() {
    f := Fx()
    f.thread.Vars["A_Foo"] := VarValues.Import(NewMap("k", "v"))
    f.thread.HiddenVars["A_H"] := 1
    f.thread.Loops.Visible["A_Index"] := VarValues.Import(NewMap("k", "v"))
    clone := f.thread.Clone("thr2")
    clone.Vars["A_Foo"]["k"] := "changed"
    clone.Loops.Visible["A_Index"]["k"] := "changed"
    Assert.Equal(f.thread.Vars["A_Foo"]["k"], "v", "thread variables are copied")
    Assert.Equal(f.thread.Loops.Visible["A_Index"]["k"], "v", "loop variables are copied")
    Assert.Equal(clone.HiddenVars["A_H"], 1)
}

TestRun.Case("names: destination by name and location (v1 Var_RetrieveDestination)", CheckDestination)
TestRun.Case("names: the rule of Var_CheckName", CheckNameRule)
TestRun.Case("location: A_ is loop, thread, built-in; prefixes; instance", CheckLocationByName)
TestRun.Case("location: the name decides the table", CheckNameDecidesTheTable)
TestRun.Case("hidden variables per scope", CheckHiddenVariables)
TestRun.Case("common place: only global, static and built-in", CheckCommonPlace)
TestRun.Case("SetVar: scopes and the errors of v1", CheckSetVarRules)
TestRun.Case("values are copies; an Array becomes a Map", CheckValuesAreCopies)
TestRun.Case("objects: integer keys and the order of v1", CheckKeysAndOrder)
TestRun.Case("paths: read and delete members", CheckPaths)
TestRun.Case("paths into global objects", CheckGlobalAndStaticPaths)
TestRun.Case("resolver: reads and assignments in all scopes", CheckResolver)
TestRun.Case("resolver: assignment to members", CheckResolverPaths)
TestRun.Case("resolver: an A_ name cannot be assigned", CheckResolverRefusesAnAName)
TestRun.Case("resolver: an assigned object is a copy", CheckAssignmentCopies)
TestRun.Case("built-in variables", CheckBuiltIns)
TestRun.Case("working directory of a flow", CheckWorkingDir)
TestRun.Case("replace: %var% as v1 Var_replaceVariables", CheckReplace)
TestRun.Case("JSON text of objects", CheckJsonText)
TestRun.Case("ListVars per scope and all", CheckListVars)
TestRun.Case("loop stack: inner loop hides and restores outer loop variables", CheckLoopStackKeepsOuterLoopVariables)
TestRun.Case("loop stack: entering a loop shares the outer snapshot (F-0097)", CheckLoopStackSharesTheSnapshot)
TestRun.Case("loop stack: nested snapshots stay apart (F-0097)", CheckNestedSnapshotsStayApart)
TestRun.Case("thread clone copies its variables", CheckThreadCloneCopiesVariables)

TestRun.Finish()
