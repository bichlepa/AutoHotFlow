#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\LoopOps.ahk
#Include ..\lib\TextOps.ahk

; Loop Through Files of the package Default (WI-0121): one pass per file or folder that the pattern finds. Specification: the
; help text of v1 (help/en/Loops/Loop_Through_Files.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Loops/Loop_Through_Files.ahk). The entry points and the loop variables: lib/LoopOps.ahk.
;
;   file              the file pattern (a path or a wildcard pattern, relative to the working directory of the flow)
;   OperateOnWhat     Files, FilesAndFolders or Folders
;   Recurse           recurse into the subfolders
;
; The first worker loop (ELEMENT-API-V2 7.1): every pass is a job, and the job learns the entry point through
; ctx.entryPoint (PROTOCOL 4.5). The head pass lists the files once (Loop Files) and stores the list as the hidden loop
; variable A_LoopCurrentList, as the list loops do: a later pass reads one member of it and lists nothing, so a pass costs
; one job and the files created in the body do not change the passes (the same as v1, which also listed at the head).
;
; Loop variables of a pass (the names of v1): A_LoopFileName, A_LoopFileExt, A_LoopFilePath, A_LoopFileLongPath (the full
; path; v2 calls it A_LoopFileFullPath), A_LoopFileShortPath, A_LoopFileShortName, A_LoopFileDir, A_LoopFileTimeModified,
; A_LoopFileTimeCreated, A_LoopFileTimeAccessed, A_LoopFileAttrib, A_LoopFileSize, A_LoopFileSizeKB, A_LoopFileSizeMB and
; A_LoopFileNameNoExt (the name without the extension, from the full path).
class Loop_Loop_Through_Files extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Loop Through Files")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Options")},
        {type: "Radio", id: "OperateOnWhat", default: "Files", choices: [Lang("Operate on files"), Lang("Operate on files and folders"), Lang("Operate on folders")], result: "enum", enum: ["Files", "FilesAndFolders", "Folders"]},
        {type: "Checkbox", id: "Recurse", default: 0, label: Lang("Recurse into subfolders")}
    ]

    static GenerateName(ctx, params) {
        textRecursive := DialogOps.Truthy(TextOps.Par(params, "Recurse")) ? Lang("Recursive") : Lang("Not recursive")
        return Lang("Loop Through Files") " - " TextOps.Par(params, "file") " - " this._KindText(TextOps.Par(params, "OperateOnWhat")) " - " textRecursive
    }

    static Run(ctx, params) {
        entry := LoopOps.Entry(ctx)
        if (entry = "break") {
            ctx.Finish("tail")
            return
        }
        if (entry = "head") {
            p := ctx.EvalParams(params)
            items := LoopOps.NewMap()
            n := 0
            Loop Files, p.file, FileOps.Mode(p.OperateOnWhat, DialogOps.Truthy(p.Recurse)) {
                n += 1
                items[n] := this._FileVars()
            }
            if (n = 0) {
                ctx.Finish("tail")          ; no file: no pass at all
                return
            }
            LoopOps.SetSnapshot(ctx, items)
            index := 1
        } else {
            index := LoopOps.NextIndex(ctx)
        }
        item := LoopOps.Item(ctx, index)
        if (LoopOps.IsNone(item)) {
            ctx.Finish("tail")              ; the last file was done
            return
        }
        LoopOps.SetIndex(ctx, index)
        for name, value in item
            FileOps.SetOutput(ctx, name, value, "loop")      ; the A_ names are loop variables
        ctx.Finish("head")
    }

    ; The loop variables of the file that the innermost file loop reads now (called inside the loop body only).
    static _FileVars() {
        SplitPath(A_LoopFileFullPath, , , , &nameNoExt)
        m := Map()
        m["A_LoopFileName"] := A_LoopFileName
        m["A_LoopFileExt"] := A_LoopFileExt
        m["A_LoopFilePath"] := A_LoopFilePath
        m["A_LoopFileLongPath"] := A_LoopFileFullPath
        m["A_LoopFileShortPath"] := A_LoopFileShortPath
        m["A_LoopFileShortName"] := A_LoopFileShortName
        m["A_LoopFileDir"] := A_LoopFileDir
        m["A_LoopFileTimeModified"] := A_LoopFileTimeModified
        m["A_LoopFileTimeCreated"] := A_LoopFileTimeCreated
        m["A_LoopFileTimeAccessed"] := A_LoopFileTimeAccessed
        m["A_LoopFileAttrib"] := A_LoopFileAttrib
        m["A_LoopFileSize"] := A_LoopFileSize
        m["A_LoopFileSizeKB"] := A_LoopFileSizeKB
        m["A_LoopFileSizeMB"] := A_LoopFileSizeMB
        m["A_LoopFileNameNoExt"] := nameNoExt
        return m
    }

    ; The text of the operation choice, as the name of the element shows it (the v1 texts).
    static _KindText(choice) {
        switch choice {
            case "Files": return Lang("Operate on files")
            case "FilesAndFolders": return Lang("Operate on files and folders")
            case "Folders": return Lang("Operate on folders")
        }
        return ""
    }
}
