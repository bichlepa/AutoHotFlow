#Requires AutoHotkey v2.0
#SingleInstance Off

; Test entry of the role engine (WI-0047-PREP): the product entry src\entry\engine.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\engine\Engine.ahk
#Include ..\..\..\..\src\entry\generated\Elements_engine.ahk
#Include generated\TestElements_engine.ahk

RoleRegistry.Register("engine", Engine)
AhfMain()
