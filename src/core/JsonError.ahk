#Requires AutoHotkey v2.0
#Include ErrCode.ahk
#Include AhfError.ahk

class JsonError extends AhfError {
    code := ErrCode.BAD_JSON
}
