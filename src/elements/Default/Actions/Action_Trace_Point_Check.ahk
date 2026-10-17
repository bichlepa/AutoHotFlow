#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Trace point check of the package Default (WI-0052): checks which trace points the instance has passed so far
; (Action_Trace_Point) and ends with "exception" if that does not match. Specification: the help text of v1
; (help/en/Actions/Trace_Point_Check.html); parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Trace_Point_Check.ahk), whose code has several typos that the help text does not
; have (MIGRATION M-0056).
;
;   MustPassTracepointsAll      1: every trace point of the flow must have been passed. The trace points selected in the
;                               list MustNotPassTracepoints are the exceptions: they are not required
;   MustPassTracepoints         otherwise: the selected trace points must have been passed (may be none)
;   MustNotPassTracepointsAll   1: no trace point of the flow may have been passed. The trace points selected in the list
;                               MustPassTracepoints are the exceptions
;   MustNotPassTracepoints      otherwise: the selected trace points must not have been passed (may be none)
; A trace point is named "<ID> (<element ID>)", as Action_Trace_Point records it. The two "all" options exclude each
; other (CheckSettings clears the other one); a flow file that has both set ends with "exception".
;
; The lists are read from the stored parameters of the element (ctx.GetElementPars): Run receives a list as the empty
; text. The choices of the lists are the trace points of the flow, asked through the context of the editor.
class Action_Trace_Point_Check extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Programmer"
    static Stability := "Stable"
    ; v1: the form is updated after every edit of a parameter (the editor decides how, S0007)
    static UpdateOnEdit := true

    ; The hidden instance variable that Action_Trace_Point writes (the same text there; a class does not use another)
    static PASSED_VAR := "passed_Tracepoints"

    static Name() => Lang("Trace_Point_Check")
    static Category() => Lang("Debugging")

    ; The lists offer the trace points of the flow. ctx is the context of the editor; without one (the engine, the smoke
    ; test) the lists have no choices.
    static Parameters(ctx) {
        choices := this.TracePointNames(ctx)
        return [
            {type: "Label", label: Lang("Trace points which must have been passed")},
            {type: "Checkbox", id: "MustPassTracepointsAll", default: 0, label: Lang("All trace points")},
            {type: "ListBox", id: "MustPassTracepoints", result: "String", choices: choices, multi: true},
            {type: "Label", label: Lang("Trace points which must not have been passed")},
            {type: "Checkbox", id: "MustNotPassTracepointsAll", default: 0, label: Lang("All trace points")},
            {type: "ListBox", id: "MustNotPassTracepoints", result: "String", choices: choices, multi: true}
        ]
    }

    static GenerateName(ctx, params) {
        mustPassSelected := this.ListOf(params.HasProp("MustPassTracepoints") ? params.MustPassTracepoints : "").Length
        mustNotPassSelected := this.ListOf(params.HasProp("MustNotPassTracepoints") ? params.MustNotPassTracepoints : "").Length
        if (this.IsOn(params, "MustPassTracepointsAll")) {
            text := mustNotPassSelected ? Lang("Must pass all trace points with exceptions") : Lang("Must pass all trace points")
        } else if (this.IsOn(params, "MustNotPassTracepointsAll")) {
            text := mustPassSelected ? Lang("Must not pass any trace point with exceptions") : Lang("Must not pass any trace point")
        } else if (mustPassSelected && mustNotPassSelected) {
            text := Lang("Must pass some selected trace points and must not pass some selected trace points")
        } else if (mustPassSelected) {
            text := Lang("Must pass selected trace points")
        } else if (mustNotPassSelected) {
            text := Lang("Must not pass selected trace points")
        } else {
            text := Lang("No checks")
        }
        return Lang("Trace_Point_Check") " - " text
    }

    static CheckSettings(form, params, staticValues) {
        if (this.IsOn(params, "MustPassTracepointsAll")) {
            form.Disable("MustPassTracepoints", true)
            form.Disable("MustNotPassTracepointsAll", true)
            form.SetValue("MustNotPassTracepointsAll", false)
        } else {
            form.Enable("MustPassTracepoints", true)
            form.Enable("MustNotPassTracepointsAll", true)
        }
        if (this.IsOn(params, "MustNotPassTracepointsAll")) {
            form.Disable("MustNotPassTracepoints", true)
            form.Disable("MustPassTracepointsAll", true)
            form.SetValue("MustPassTracepointsAll", false)
        } else {
            form.Enable("MustNotPassTracepoints", true)
            form.Enable("MustPassTracepointsAll", true)
        }
    }

    static Run(ctx, params) {
        ctx.EvalParams(params, "MustPassTracepoints,MustNotPassTracepoints")    ; no parameter needs a value here
        pars := ctx.GetElementPars(ctx.elementId)
        mustAll := this.IsOn(pars, "MustPassTracepointsAll")
        notAll := this.IsOn(pars, "MustNotPassTracepointsAll")
        if (mustAll && notAll)
            throw ElementError("Both 'All trace points' options are set; they exclude each other.")
        selectedMust := this.ListOf(pars.HasProp("MustPassTracepoints") ? pars.MustPassTracepoints : "")
        selectedNot := this.ListOf(pars.HasProp("MustNotPassTracepoints") ? pars.MustNotPassTracepoints : "")
        allPoints := this.TracePointNames(ctx)
        mustPass := mustAll ? this.Without(allPoints, selectedNot) : selectedMust
        mustNotPass := notAll ? this.Without(allPoints, selectedMust) : selectedNot

        passed := this.SetOf(this.ListOf(ctx.GetVar(this.PASSED_VAR, "", true)))
        missing := []
        for name in mustPass {
            if (!passed.Has(name))
                missing.Push(name)
        }
        forbidden := []
        for name in mustNotPass {
            if (passed.Has(name))
                forbidden.Push(name)
        }
        if (missing.Length = 0 && forbidden.Length = 0) {
            ctx.Finish("normal")
            return
        }
        message := ""
        if (missing.Length)
            message .= Lang("%1% tracepoints were not passed which must have been passed: %2%.", missing.Length
                , this.Joined(missing)) " "
        if (forbidden.Length)
            message .= Lang("%1% tracepoints were passed which must not have been passed: %2%.", forbidden.Length
                , this.Joined(forbidden))
        ctx.Finish("exception", Trim(message))
    }

    ; The trace points of the flow of ctx as "<ID> (<element ID>)", in the order of the flow file. "" or a context
    ; without the flow functions gives none (the editor).
    static TracePointNames(ctx) {
        names := []
        if (!IsObject(ctx) || !HasMethod(ctx, "GetElementIdsOfClass"))
            return names
        for id in ctx.GetElementIdsOfClass("Action_Trace_Point") {
            pars := ctx.GetElementPars(id)
            names.Push((pars.HasProp("ID") ? pars.ID : "") " (" id ")")
        }
        return names
    }

    ; The entries of a stored list: an Array, or a Map as v1 wrote an empty list ({}) or a list ({"1": ...}); anything
    ; else is no list. Entries are texts.
    static ListOf(value) {
        out := []
        if (value is Array) {
            for item in value
                out.Push(IsSet(item) ? String(item) : "")
        } else if (value is Map) {
            for key, item in value
                out.Push(String(item))
        }
        return out
    }

    ; A set (Map, case-insensitive like the comparison of v1) of the texts of an Array
    static SetOf(list) {
        m := Map()
        m.CaseSense := "Off"
        for item in list
            m[item] := true
        return m
    }

    ; The entries of list that are not in other, in the order of list
    static Without(list, other) {
        skip := this.SetOf(other)
        out := []
        for item in list {
            if (!skip.Has(item))
                out.Push(item)
        }
        return out
    }

    static Joined(list) {
        out := ""
        for item in list
            out .= (A_Index = 1 ? "" : ", ") item
        return out
    }

    ; True if a checkbox of the parameters is on (1, "1", true; not 0, "0", "" or missing)
    static IsOn(params, id) {
        if (!params.HasProp(id))
            return false
        value := params.%id%
        return !IsObject(value) && value != "" && value != 0 && value != "0"
    }
}
