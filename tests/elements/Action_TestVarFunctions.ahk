#Requires AutoHotkey v2.0
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\elements\base\AhfElement.ahk
#Include ..\..\src\elements\base\ElementRegistry.ahk

; Test element of WI-50 (inline): calls every variable function of the context in a fixed order and writes a report of
; what each call returned (or the text of the error it threw) into the global variable global_varreport_<Tag>. Its twin
; Action_TestVarFunctionsWorker runs the same Exercise in a worker, where every call goes to the engine
; (cmd.engine.var.*): the two reports must be equal (tests/integration/test_worker_vars.py).
;
; The report has one line per call: "<label> = <Type>:<JSON of the value>" or "<label> ! <error text>". Lists of names
; are filtered to the names this element makes, so variables of other tests (global ones) do not show.
class Action_TestVarFunctions extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: every variable function"
    static Category() => "Test"

    static Run(ctx, params) {
        report := Action_TestVarFunctions.Exercise(ctx)
        ctx.SetVar("global_varreport_" params.Tag, report)
        ctx.Finish("normal")
    }

    static Exercise(ctx) {
        out := []
        T := Action_TestVarFunctions
        ; set
        T.Step(out, "set text", () => ctx.SetVar("tv_text", "hello"))
        T.Step(out, "set int", () => ctx.SetVar("tv_int", 42))
        T.Step(out, "set float", () => ctx.SetVar("tv_float", 2.5))
        T.Step(out, "set digits text", () => ctx.SetVar("tv_numtext", "007"))
        T.Step(out, "set array", () => ctx.SetVar("tv_list", ["a", "b", Map("k", "v")]))
        T.Step(out, "set map", () => ctx.SetVar("tv_map", Map(1, "one", "Key", 2, "10", "ten")))
        T.Step(out, "set thread", () => ctx.SetVar("A_tvThread", "t", "thread"))
        T.Step(out, "set loop", () => ctx.SetVar("A_tvLoop", "l", "loop"))
        T.Step(out, "set A_ without scope", () => ctx.SetVar("A_tvNo", 1))
        T.Step(out, "set bad name", () => ctx.SetVar("tv bad", 1))
        T.Step(out, "set empty name", () => ctx.SetVar("", 1))
        T.Step(out, "set plain name with scope", () => ctx.SetVar("tv_x", 1, "thread"))
        T.Step(out, "set hidden", () => ctx.SetVar("tv_hidden", "h", "", true))
        T.Step(out, "set hidden global", () => ctx.SetVar("global_tvh", 1, "", true))
        T.Step(out, "set global", () => ctx.SetVar("global_tvg", "g"))
        T.Step(out, "set static", () => ctx.SetVar("static_tvs", 3))
        T.Step(out, "set an object that is no value", () => ctx.SetVar("tv_obj", ElementError("x")))
        ; get, type, location
        for name in ["tv_text", "TV_TEXT", "tv_int", "tv_float", "tv_numtext", "tv_list", "tv_list.2", "tv_list.3.k"
                , "tv_map", "tv_map.1", "tv_map.10", "A_tvThread", "A_tvLoop", "tv_hidden", "global_tvg", "static_tvs"
                , "A_Space", "A_LF", "tv_missing", "tv_list.9"] {
            T.Step(out, "get " name, T.Getter(ctx, name))
            T.Step(out, "type " name, T.Typer(ctx, name))
            T.Step(out, "location " name, T.Locator(ctx, name))
        }
        T.Step(out, "get hidden", () => ctx.GetVar("tv_hidden", "<default>", true))
        T.Step(out, "type hidden", () => ctx.GetVarType("tv_hidden", true))
        T.Step(out, "location hidden", () => ctx.GetVarLocation("tv_hidden", true))
        T.Step(out, "VarLocation", () => ctx.VarLocation("tv_int"))
        ; lists
        for scope in ["instance", "thread", "loop", "static", "global", ""]
            T.Step(out, "list '" scope "'", T.Lister(ctx, scope))
        T.Step(out, "list of an unknown scope", () => ctx.ListVars("nowhere"))
        ; substitution, expressions, scripts
        T.Step(out, "replace", () => ctx.ReplaceVariables("a %tv_text% b %tv_int% c %tv_list% d %tv_missing% e"))
        T.Step(out, "replace objects", () => ctx.ReplaceVariables("[%tv_map%]", true))
        T.Step(out, "eval numbers", () => ctx.EvaluateExpression("tv_int * 2 + tv_float"))
        T.Step(out, "eval members", () => ctx.EvaluateExpression("tv_list[3].k . tv_text"))
        T.Step(out, "eval object", () => ctx.EvaluateExpression("tv_map"))
        T.Step(out, "eval type error", () => ctx.EvaluateExpression("tv_text + 1"))
        T.Step(out, "eval syntax error", () => ctx.EvaluateExpression("1 +"))
        T.Step(out, "eval assignment", () => ctx.EvaluateExpression("tv_new := tv_int - 2"))
        T.Step(out, "get assigned", () => ctx.GetVar("tv_new"))
        T.Step(out, "script", () => ctx.EvaluateScript("tv_a := tv_int + 1`ntv_b := tv_a * 2"))
        T.Step(out, "script error", () => ctx.EvaluateScript("tv_a := `n)"))
        ; instance variables as a whole
        T.Step(out, "export instance", () => ctx.ExportInstanceVars())
        T.Step(out, "import instance", () => ctx.ImportInstanceVars(Map("imp_a", 1, "imp_b", Map("x", [1, 2]), "bad name", 3)))
        T.Step(out, "get imported", () => ctx.GetVar("imp_b.x.2"))
        T.Step(out, "get skipped import", () => ctx.GetVar("bad name", "<default>"))
        T.Step(out, "import a text", () => ctx.ImportInstanceVars("no map"))
        ; delete
        T.Step(out, "delete text", () => ctx.DeleteVar("tv_text"))
        T.Step(out, "delete text again", () => ctx.DeleteVar("tv_text"))
        T.Step(out, "delete member", () => ctx.DeleteVar("tv_list.1"))
        T.Step(out, "list after member delete", () => ctx.GetVar("tv_list"))
        T.Step(out, "delete built-in", () => ctx.DeleteVar("A_Space"))
        T.Step(out, "delete hidden", () => ctx.DeleteVar("tv_hidden", true))
        T.Step(out, "delete global", () => ctx.DeleteVar("global_tvg"))
        T.Step(out, "delete static", () => ctx.DeleteVar("static_tvs"))
        T.Step(out, "delete thread", () => ctx.DeleteVar("A_tvThread"))
        ; names
        T.Step(out, "name ok", () => ctx.CheckVarName("ok"))
        T.Step(out, "name with digit", () => ctx.CheckVarName("1x"))
        T.Step(out, "name with space", () => ctx.CheckVarName("a b"))
        T.Step(out, "list at the end", T.Lister(ctx, ""))
        text := ""
        for line in out
            text .= line "`n"
        return text
    }

    ; One call: its value or the text of its error, as one line of the report.
    static Step(out, label, fn) {
        try {
            value := fn()
        } catch as e {
            out.Push(label " ! " e.Message)
            return
        }
        out.Push(label " = " Action_TestVarFunctions.Render(IsSet(value) ? value : "<unset>"))
    }

    ; Closures of their own per name (a lambda in a loop would see the last name only).
    static Getter(ctx, name) => () => ctx.GetVar(name, "<default>")
    static Typer(ctx, name) => () => ctx.GetVarType(name)
    static Locator(ctx, name) => () => ctx.GetVarLocation(name)
    static Lister(ctx, scope) => () => Action_TestVarFunctions.Own(ctx.ListVars(scope))

    ; The names that this element makes (and the thread variables of the trigger), in their order.
    static Own(names) {
        out := []
        for name in names {
            if (RegExMatch(name, "i)^(tv_|A_tv|global_tv|static_tv|imp_|A_Trigger)"))
                out.Push(name)
        }
        return out
    }

    ; "<Type>:<JSON>" of a value; Map keys as texts, Arrays as lists.
    static Render(value) => Type(value) ":" Json.Stringify(Action_TestVarFunctions.Plain(value))

    static Plain(value) {
        if (value is Map) {
            m := Map()
            for k, v in value
                m[Type(k) = "Integer" ? "#" k : String(k)] := Action_TestVarFunctions.Plain(v)
            return m
        }
        if (value is Array) {
            a := []
            for v in value
                a.Push(Action_TestVarFunctions.Plain(v))
            return a
        }
        if (IsObject(value))
            return "<" Type(value) ">"
        return value
    }
}

ElementRegistry.Register(Action_TestVarFunctions)
