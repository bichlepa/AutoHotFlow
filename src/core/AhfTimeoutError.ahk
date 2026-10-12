#Requires AutoHotkey v2.0
#Include ErrCode.ahk
#Include AhfError.ahk

class AhfTimeoutError extends AhfError {
    code := ErrCode.TIMEOUT
}
