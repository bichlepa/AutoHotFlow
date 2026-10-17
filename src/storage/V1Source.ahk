#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include StoragePaths.ahk
#Include AtomicFile.ahk
#Include VarFiles.ahk

; Read-only access to a v1 data folder and to the autostart shortcut of v1 (WI-0076, REQ-MIG-060, E0068, PROTOCOL 4.6).
; The folder comes from the user's dialog. Nothing is written there: the functions of this class only list and read,
; except RemoveAutostart, which deletes the one shortcut that points to v1 and only after the user agreed (the manager asks).
;
; Layout of the v1 data folder (the same variable layout as v2, WI-0012): "Saved Flows\<name>.json" (the subfolder
; "demo flows" is not listed), "Variables\<name>.ahfvd|.ahfvar" and "Variables\<flowId>\<name>.ahfvd|.ahfvar".
class V1Source {
    static FLOWS_DIR := "Saved Flows"
    static VARS_DIR := "Variables"
    static SHORTCUT := "AutoHotFlow.lnk"
    ; v1 writes the path of AutoHotFlow.exe when it is in the folder, else the path of AutoHotFlow.ahk (v1 GetAhfPath)
    static V1_NAMES := ["autohotflow.exe", "autohotflow.ahk"]

    ; The folder as an absolute path of an existing folder. Throws bad_payload for a relative path, not_found for a missing one.
    static Root(dir) {
        text := String(dir)
        if (!RegExMatch(text, "^[A-Za-z]:\\") || InStr(text, "`n") || InStr(text, "`r"))
            throw AhfError("the v1 folder must be an absolute path", ErrCode.BAD_PAYLOAD)
        if (!DirExist(text))
            throw AhfError("the v1 folder '" text "' does not exist", ErrCode.NOT_FOUND)
        return text
    }

    ; Map(flows, vars): the names of the flow files (sorted) and the variables as Maps (scope, flowId, name).
    static List(dir) {
        root := V1Source.Root(dir)
        flows := []
        loop files, root "\" V1Source.FLOWS_DIR "\*.json"
            flows.Push(SubStr(A_LoopFileName, 1, -5))
        vars := []
        for name in VarFiles.List(root, "global", "")["names"]
            vars.Push(Map("scope", "global", "flowId", "", "name", name))
        varsDir := root "\" V1Source.VARS_DIR
        folders := []
        if (DirExist(varsDir)) {
            loop files, varsDir "\*", "D"
                if (InStr(A_LoopFileAttrib, "D"))
                    folders.Push(A_LoopFileName)
        }
        for folder in StoragePaths.SortStrings(folders) {
            ; a folder that is not a flow ID (a name that VarFiles refuses) holds no variables of a flow
            try {
                names := VarFiles.List(root, "static", folder)["names"]
            } catch {
                continue
            }
            for name in names
                vars.Push(Map("scope", "static", "flowId", folder, "name", name))
        }
        return Map("flows", StoragePaths.SortStrings(flows), "vars", vars)
    }

    ; Map(text) of the flow file "Saved Flows\<name>.json"; not_found when it is missing.
    static ReadFlow(dir, name) {
        root := V1Source.Root(dir)
        StoragePaths.CheckName(name, "flow name")
        filePath := root "\" V1Source.FLOWS_DIR "\" name ".json"
        if (FileExist(filePath) = "")
            throw AhfError("flow file '" name ".json' not found in the v1 folder", ErrCode.NOT_FOUND)
        return Map("text", AtomicFile.ReadText(filePath))
    }

    ; Map(exists, type, content) of one variable (VarFiles.Get, read only).
    static ReadVar(dir, scope, flowId, name) => VarFiles.Get(V1Source.Root(dir), scope, flowId, name)

    ; Map(exists, v1, target) of the shortcut AutoHotFlow.lnk in the startup folder. v1 is true when the target is the
    ; executable of v1 (AutoHotFlow.exe); the v2 shortcut targets AutoHotkey64.exe.
    static Autostart(startupDir) {
        filePath := V1Source._Shortcut(startupDir)
        if (FileExist(filePath) = "")
            return Map("exists", Json.Bool(false), "v1", Json.Bool(false), "target", "")
        target := ""
        try {
            target := ComObject("WScript.Shell").CreateShortcut(filePath).TargetPath
        } catch as e {
            throw AhfError("the shortcut '" filePath "' cannot be read: " e.Message, ErrCode.INTERNAL)
        }
        SplitPath(target, &targetName)
        return Map("exists", Json.Bool(true), "v1", Json.Bool(V1Source._IsV1Name(targetName)), "target", target)
    }

    ; Deletes the shortcut when it points to v1. Map(removed): false when there is no shortcut. denied for a shortcut of another
    ; program (it is kept).
    static RemoveAutostart(startupDir) {
        state := V1Source.Autostart(startupDir)
        if (!V1Source._Truth(state["exists"]))
            return Map("removed", Json.Bool(false))
        if (!V1Source._Truth(state["v1"]))
            throw AhfError("the shortcut does not point to AutoHotFlow v1, it is kept", ErrCode.DENIED)
        try {
            FileDelete(V1Source._Shortcut(startupDir))
        } catch as e {
            throw AhfError("the shortcut cannot be deleted: " e.Message, ErrCode.INTERNAL)
        }
        return Map("removed", Json.Bool(true))
    }

    ; A truth value of a state Map (Json.Bool gives the sentinel objects, which are true or false too).
    static _Truth(v) => (v == Json.True || (!IsObject(v) && (v = 1 || v = "true")))

    static _IsV1Name(fileName) {
        for name in V1Source.V1_NAMES {
            if (StrLower(fileName) = name)
                return true
        }
        return false
    }

    static _Shortcut(startupDir) {
        text := String(startupDir)
        if (!RegExMatch(text, "^[A-Za-z]:\\") || !DirExist(text))
            throw AhfError("the startup folder '" text "' does not exist", ErrCode.BAD_PAYLOAD)
        return text "\" V1Source.SHORTCUT
    }
}
