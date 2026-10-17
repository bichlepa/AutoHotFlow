#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Test entry of the role triggerhost (WI-0047-PREP): the product entry src\entry\triggerhost.ahk plus the test elements of the same
; modes (generated\TestElements_<role>.ahk). The supervisor of the test entry starts the role from here.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\triggerhost\TriggerHost.ahk
#Include ..\..\..\..\src\entry\generated\Elements_triggerhost.ahk
#Include generated\TestElements_triggerhost.ahk

RoleRegistry.Register("triggerhost", TriggerHost)
AhfMain()
