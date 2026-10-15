#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry of the role manager (WI-0047-PREP): the product entry src\entry\manager.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\manager\StubManager.ahk

RoleRegistry.Register("manager", StubManager)
AhfMain()
