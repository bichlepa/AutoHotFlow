#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry of the role storage (WI-0047-PREP): the product entry src\entry\storage.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\storage\Storage.ahk

RoleRegistry.Register("storage", Storage)
AhfMain()
