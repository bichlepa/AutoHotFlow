#Requires AutoHotkey v2.0
#Include ErrCode.ahk

; Base class. Message is the Error.Message property, code is set from the constructor.
class AhfError extends Error {
    code := ErrCode.INTERNAL

    __New(message := "", code := "", extra := "") {
        super.__New(message, , extra)
        if (code != "")
            this.code := code
    }
}
