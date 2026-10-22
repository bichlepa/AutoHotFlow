#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ProcessOps.ahk
#Include ..\lib\TextOps.ahk

; Action Set process priority of the package Default (WI-0123): changes the priority class of the first process that
; matches a name or a PID (ProcessSetPriority). Specification: the help text of v1 (help/en/Actions/Set_Process_Priority.md).
; Class ID, parameter IDs, defaults, enum values and language keys are those of v1
; (Source_Elements/Default/Actions/Set_process_priority.ahk).
;
; Worker element (process access). Realtime needs rights that the user may not have; AutoHotkey then gives 0 and the
; element ends with the v1 text. The PID is the thread variable A_Pid.
class Action_Set_Process_Priority extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Set Process Priority")
    static Category() => Lang("Process")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Process name or ID")},
        {type: "Edit", id: "ProcessName", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Priority")},
        {type: "Radio", id: "Priority", default: "Normal", result: "enum", choices: [Lang("Low"), Lang("Below normal"), Lang("Normal"), Lang("Above normal"), Lang("High"), Lang("Realtime")], enum: ["Low", "BelowNormal", "Normal", "AboveNormal", "High", "Realtime"]}
    ]

    static GenerateName(ctx, params) {
        levels := Map("Low", "Low", "BelowNormal", "Below normal", "Normal", "Normal", "AboveNormal", "Above normal", "High", "High", "Realtime", "Realtime")
        priority := TextOps.Par(params, "Priority")
        return Lang("Set Process Priority") " - " TextOps.Par(params, "ProcessName") " - " Lang(levels.Get(priority, priority))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        target := ProcessOps.Target(p.ProcessName)
        pid := 0
        try
            pid := ProcessSetPriority(p.Priority, target)     ; throws when no process matches (AutoHotkey)
        catch
            pid := 0
        if (pid = 0) {
            if (ProcessExist(target) = 0)
                throw ElementError(Lang("Process '%1%' does not exist", p.ProcessName))
            throw ElementError(Lang("Priority of process '%1%' could not be changed", p.ProcessName))
        }
        ctx.SetVar("A_Pid", pid, "thread")
        ctx.Finish("normal")
    }
}
