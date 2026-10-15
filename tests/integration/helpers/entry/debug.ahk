#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry of the role debug (WI-0047-PREP): the product entry src\entry\debug.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\debugview\DebugView.ahk

RoleRegistry.Register("debug", DebugView)
AhfMain()
