#Requires AutoHotkey v2.0
#Include ..\..\core\Json.ahk
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element of WI-0041: changes variables through the element API, so that the tests can set, delete and read
; global and static variables of a running engine (there is no other way yet: the variable elements come with WI-0043).
;   Steps  JSON text of an array of steps, run in this order. A step is an object with
;          op     "set" (store the JSON value as it is: text, number or object), "delete", or "probe"
;          name   the variable; its name decides the scope (global_, static_, or an instance variable)
;          location  optional, only for "set": "thread" or "loop" for a name that starts with A_ (WI-0043)
;          value  the value of "set"
;          "probe" copies the text form of the variable to the global variable global_probe_<name> and its type
;          ("String", "Integer", "Float", "Map", or "<missing>") to global_probetype_<name> and its location
;          ("instance", "thread", "global", "static", "builtin", or "<missing>") to global_probeloc_<name>; with this
;          the tests read what the engine loaded from the files, through the files the probe variables are written to.
class Action_TestSetVar extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: set, delete or probe variables"
    static Category() => "Test"

    static Run(ctx, params) {
        steps := Json.Parse(params.HasProp("Steps") ? params.Steps : "[]")
        for step in steps {
            op := StrLower(step.Get("op", "set"))
            name := step.Get("name", "")
            switch op {
                case "set":
                    result := ctx.SetVar(name, step.Get("value", ""), step.Get("location", ""))
                case "delete":
                    result := ctx.DeleteVar(name)
                case "probe":
                    result := Action_TestSetVar.Probe(ctx, name)
                default:
                    throw ElementError("TestSetVar: unknown op '" op "'")
            }
            if (!result)
                throw ElementError("TestSetVar: '" op "' of '" name "' did not work")
        }
        ctx.Finish("normal")
    }

    ; A Map of a variable as plain JSON data: a Map with exactly the keys 1..n becomes an Array, other keys become texts.
    static Plain(value) {
        if (!(value is Map))
            return value
        isList := value.Count > 0
        loop value.Count {
            if (!value.Has(A_Index))
                isList := false
        }
        out := isList ? [] : Map()
        for key, item in value {
            if (isList)
                out.Push(Action_TestSetVar.Plain(item))
            else
                out[String(key)] := Action_TestSetVar.Plain(item)
        }
        return out
    }

    static Probe(ctx, name) {
        if (!ctx.VarLocation(name)) {
            ctx.SetVar("global_probe_" name, "<missing>")
            ctx.SetVar("global_probeloc_" name, "<missing>")
            return ctx.SetVar("global_probetype_" name, "<missing>")
        }
        value := ctx.GetVar(name)
        ctx.SetVar("global_probeloc_" name, ctx.VarLocation(name))
        ctx.SetVar("global_probe_" name, (value is Map) ? Json.Stringify(Action_TestSetVar.Plain(value)) : String(value))
        return ctx.SetVar("global_probetype_" name, (value is Map) ? "Map" : Type(value))
    }
}

ElementRegistry.Register(Action_TestSetVar)
