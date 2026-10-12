#Requires AutoHotkey v2.0
#Include ErrCode.ahk
#Include AhfError.ahk

class ProtocolError extends AhfError {
    code := ErrCode.BAD_PAYLOAD
}
