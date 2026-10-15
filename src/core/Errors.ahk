#Requires AutoHotkey v2.0
; Error classes and error codes shared by all processes (doc/PROTOCOL.md section 2). Since WI-0029 each class has its
; own file; this file only includes them, so that the many `#Include Errors.ahk` lines stay as they are.
; Every exception carries a `code`. Subclasses preset it; AhfError takes it as second argument.
#Include ErrCode.ahk
#Include AhfError.ahk
#Include ProtocolError.ahk
#Include AhfTimeoutError.ahk
#Include ElementError.ahk
#Include JsonError.ahk
