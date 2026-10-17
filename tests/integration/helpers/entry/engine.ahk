#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Test entry of the role engine (WI-0047-PREP): the product entry src\entry\engine.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\engine\Engine.ahk
#Include ..\..\..\..\src\entry\generated\Elements_engine.ahk
#Include generated\TestElements_engine.ahk
#Include ..\TestDialogProvider.ahk

TestDialogProvider.Register()   ; dialogs of elements are answered from the script of the test (E0038)
RoleRegistry.Register("engine", Engine)
AhfMain()
