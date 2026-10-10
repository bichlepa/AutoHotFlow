#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk

; Validation of the names and paths that storage accepts from other roles (WI-12, PROTOCOL 4.6).
; Every name is checked before it becomes part of a file path, so no request can leave the data
; directory. Invalid input throws AhfError with code bad_payload.
class StoragePaths {
    static MAX_NAME := 200
    ; "Flows/<name>.json", relative to the data directory. Names may contain spaces and umlauts (v1 names).
    static FLOW_PATH := '^Flows/[^/\\:*?"<>|\x00-\x1F]+\.json$'

    static FlowsDir(dataDir) => dataDir "\Flows"
    static VarsDir(dataDir) => dataDir "\Variables"
    static LogDir(dataDir) => dataDir "\Log"

    ; Absolute path of a flow file given as "Flows/<name>.json".
    static Flow(dataDir, flowPath) {
        text := String(flowPath)
        if (!RegExMatch(text, StoragePaths.FLOW_PATH) || InStr(text, ".."))
            throw AhfError("bad flow path '" text "'", ErrCode.BAD_PAYLOAD)
        return dataDir "\" StrReplace(text, "/", "\")
    }

    ; Returns the name as text if it is usable as one file or folder name, else throws.
    static CheckName(rawName, what) {
        text := String(rawName)
        if (text = "" || StrLen(text) > StoragePaths.MAX_NAME || text = "." || text = ".."
            || RegExMatch(text, '[\\/:*?"<>|\x00-\x1F]'))
            throw AhfError(what " '" text "' is not a valid name", ErrCode.BAD_PAYLOAD)
        return text
    }

    ; Sorts an Array of strings in place, ascending (insertion sort, the arrays are short).
    static SortStrings(items) {
        loop items.Length - 1 {
            i := A_Index + 1
            j := i
            while (j > 1 && StrCompare(items[j], items[j - 1]) < 0) {
                tmp := items[j]
                items[j] := items[j - 1]
                items[j - 1] := tmp
                j--
            }
        }
        return items
    }
}
