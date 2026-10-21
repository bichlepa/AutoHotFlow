#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon: the icon of the application belongs to the role tray (E0075).
#NoTrayIcon

; Test entry of the role help (WI-0111): the product entry src\entry\help.ahk. The supervisor of the test entry starts the
; role from here. The role has no element classes, so there is no test block.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\help\HelpRole.ahk

RoleRegistry.Register("help", HelpRole)
AhfMain()
