#Requires AutoHotkey v2.0
#Include ErrCode.ahk
#Include AhfError.ahk

class ElementError extends AhfError {
    code := ErrCode.EXCEPTION
}
