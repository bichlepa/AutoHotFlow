#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ProcessOps.ahk
#Include ..\lib\TextOps.ahk

; Condition Process is running of the package Default (WI-0123): yes when a process with the name or the PID exists, no
; otherwise. Specification: the help text of v1 (help/en/Conditions/Process_Is_Running.md). Class ID, parameter IDs and
; language keys are those of v1 (Source_Elements/Default/Conditions/Process_is_running.ahk).
;
; Worker element (process access). The PID of the first matching process is the thread variable A_Pid, as v1 did.
class Condition_Process_Is_Running extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Process Is Running")
    static Category() => Lang("Process")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Process name or ID")},
        {type: "Edit", id: "ProcessName", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Process Is Running") "`n" TextOps.Par(params, "ProcessName")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        pid := ProcessExist(ProcessOps.Target(p.ProcessName))
        if (pid) {
            ctx.SetVar("A_Pid", pid, "thread")
            ctx.Finish("yes")
        } else {
            ctx.Finish("no")
        }
    }
}
