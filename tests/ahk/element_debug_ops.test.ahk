#Requires AutoHotkey v2.0
; Unit tests for src/elements/Default/lib/DebugOps.ahk (WI-0056, REQ-DBG-060): the text conversion of the debug window
; (Escape, Unescape) and the rules of Write with a fake context. The window and the variable requests are covered by
; tests/integration/test_core_e_dialogs.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\lib\DebugOps.ahk

; A context that keeps the variables in a Map and answers the calls of the view as the worker does.
class FakeCtx {
    vars := Map()
    locations := Map()
    lastScope := "unset"

    ListVars(scope := "") => []
    GetVar(name, default := "") => this.vars.Has(name) ? this.vars[name] : default
    GetVarType(name) => this.vars.Has(name) ? (IsObject(this.vars[name]) ? "object" : "normal") : ""
    GetVarLocation(name) => this.locations.Get(name, "")

    DeleteVar(name) {
        if (!this.vars.Has(name))
            return 0
        this.vars.Delete(name)
        return 1
    }

    SetVar(name, value, scope := "") {
        this.lastScope := scope
        this.vars[name] := value
        return 1
    }
}

TestRun.Init()

TestRun.Case("Escape: a backslash, the tab, CR, LF and other characters", () => (
    Assert.Equal(DebugOps.Escape("a\b"), "a\\b"),
    Assert.Equal(DebugOps.Escape("x`ty`r`nz"), "x\ty\r\nz"),
    Assert.Equal(DebugOps.Escape(Chr(0xE9)), "\u00E9"),
    Assert.Equal(DebugOps.Escape("plain 123"), "plain 123")))

TestRun.Case("Unescape is the reverse of Escape", () => (
    Assert.Equal(DebugOps.Unescape(DebugOps.Escape("a\b`tc`r`nd" Chr(0xE9))), "a\b`tc`r`nd" Chr(0xE9)),
    Assert.Equal(DebugOps.Unescape("A\\"), "A\")))

TestRun.Case("Unescape: a backslash that starts no sequence, or a broken \u, throws", () => (
    Assert.Throws(() => DebugOps.Unescape("a\q")),
    Assert.Throws(() => DebugOps.Unescape("\u12")),
    Assert.Throws(() => DebugOps.Unescape("end\"))))

TestRun.Case("Write: a plain text is stored as a text", () => (
    ctx := FakeCtx(),
    view := DebugOps(ctx),
    Assert.Equal(view.Write("Foo", "hello"), ""),
    Assert.Equal(ctx.vars["Foo"], "hello"),
    Assert.Equal(view.Type("Foo"), "normal")))

TestRun.Case("Write: an object is parsed from JSON, and a text that is no JSON changes nothing", () => (
    ctx := FakeCtx(),
    view := DebugOps(ctx),
    Assert.Equal(view.Write("Obj", '{"a": 1}', true), ""),
    Assert.Equal(view.Type("Obj"), "object"),
    Assert.True(view.Write("Obj", "{ broken", true) != ""),
    Assert.Equal(view.Type("Obj"), "object", "the variable keeps its old value"),
    Assert.True(view.Write("Num", "5", true) != "", "a number is not an object")))

TestRun.Case("Write: the text is unescaped only with convert", () => (
    ctx := FakeCtx(),
    view := DebugOps(ctx),
    view.Write("Text", "one\ntwo", false, true),
    Assert.Equal(ctx.vars["Text"], "one`ntwo"),
    view.Write("Raw", "one\ntwo", false, false),
    Assert.Equal(ctx.vars["Raw"], "one\ntwo")))

TestRun.Case("Write: a loop or thread variable is set where it lives", () => (
    ctx := FakeCtx(),
    ctx.locations["A_Index"] := "loop",
    view := DebugOps(ctx),
    view.Write("A_Index", "3"),
    Assert.Equal(ctx.lastScope, "loop"),
    view.Write("Foo", "x"),
    Assert.Equal(ctx.lastScope, "")))

TestRun.Case("Text: an object is shown as JSON; with convert its backslashes are escaped as well", () => (
    ctx := FakeCtx(),
    ctx.vars["Obj"] := Map("k", "v`n"),
    view := DebugOps(ctx),
    Assert.True(InStr(view.Text("Obj", false), '"k"') > 0),
    Assert.True(InStr(view.Text("Obj", true), "\\n") > 0, "the JSON backslash of a line feed is doubled")))

TestRun.Finish()
