#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry of the role worker (WI-0047-PREP): the product entry src\entry\worker.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\worker\Worker.ahk
#Include ..\..\..\..\src\entry\generated\Elements_worker.ahk
#Include generated\TestElements_worker.ahk

RoleRegistry.Register("worker", Worker)
AhfMain()
