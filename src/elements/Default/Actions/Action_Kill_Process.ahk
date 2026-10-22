#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ProcessOps.ahk
#Include ..\lib\TextOps.ahk

; Action Kill process of the package Default (WI-0123): ends a process by its name or its PID (ProcessClose: the first
; matching process). Specification: the help text of v1 (help/en/Actions/Kill_Process.md). Class ID, parameter IDs,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Kill_Process.ahk).
;
; Worker element (process access). The process is ended abruptly, as v1 did (the help says so). A process that is still
; running after the call ends with an exception. The PID of the ended process is the thread variable A_Pid.
; Tests kill only their own child processes (WI-0123, task 1).
class Action_Kill_Process extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Kill Process")
    static Category() => Lang("Process")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Process name or ID")},
        {type: "Edit", id: "ProcessName", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Kill Process") "`n" TextOps.Par(params, "ProcessName")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        target := ProcessOps.Target(p.ProcessName)
        pid := ProcessClose(target)
        if (pid = 0) {
            if (ProcessExist(target) = 0)
                throw ElementError(Lang("Process '%1%' does not exist", p.ProcessName))
            throw ElementError(Lang("Process '%1%' could not be terminated", p.ProcessName))
        }
        ctx.SetVar("A_Pid", pid, "thread")
        ctx.Finish("normal")
    }
}
