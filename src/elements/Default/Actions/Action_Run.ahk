#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\ProcessOps.ahk
#Include ..\lib\TextOps.ahk

; Action Run of the package Default (WI-0123): starts a program, a document or a URL. Specification: the help text of v1
; (help/en/Actions/Run.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Run.ahk).
;
; Worker element (process access). The working folder is the folder of the flow ("Working directory of the flow"), or the
; one given in the parameter. The run modes are those of v1: Normal, Max, Min and Hide (ProcessOps.RunOptions). The PID of
; the started process is the thread variable A_Pid (as v1 `a_pid`); AutoHotkey gives no PID for a document or a URL, then
; it is 0.
class Action_Run extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Run")
    static Category() => Lang("Process")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Command")},
        {type: "Edit", id: "ToRun", content: ["String", "RawString"], contentID: "ToRunContent", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("Working directory")},
        {type: "Radio", id: "WhichWorkingDir", default: "Default", result: "enum", choices: [Lang("Working directory of the flow"), Lang("Following working directory")], enum: ["Default", "Specified"]},
        {type: "Folder", id: "WorkingDir", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Run mode")},
        {type: "Radio", id: "RunMode", default: "Normal", result: "enum", choices: [Lang("Run normally"), Lang("Run maximized"), Lang("Run minimized"), Lang("Run hidden")], enum: ["Normal", "Max", "Min", "Hide"]}
    ]

    static GenerateName(ctx, params) => Lang("Run") " - " TextOps.Par(params, "ToRun")

    static CheckSettings(form, params, staticValues) {
        form.Enable("WorkingDir", TextOps.Par(params, "WhichWorkingDir") = "Specified")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "WorkingDir")
        dir := ctx.GetVar("A_WorkingDir")
        if (p.WhichWorkingDir = "Specified") {
            p := ctx.EvalMoreParams(p, params, "WorkingDir")
            dir := p.WorkingDir
            if (!FileOps.IsFolder(FileOps.Attr(dir)))
                throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Folder"), dir))
        }
        pid := 0
        try
            pid := ProcessOps.Start(p.ToRun, dir, ProcessOps.RunOptions(p.RunMode))
        catch
            throw ElementError(Lang("Can't run '%1%'", p.ToRun))
        ctx.SetVar("A_Pid", pid, "thread")
        ctx.Finish("normal")
    }
}
