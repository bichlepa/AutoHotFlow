#Requires AutoHotkey v2.0
#SingleInstance Off
; The icon appears only when the role has built its menu and is not headless (Tray.Start, E0046, E0075).
#NoTrayIcon

; Test entry of the role tray (WI-0072): the product entry src\entry\tray.ahk. The supervisor of the test entry starts the
; role from here. The role has no element classes, so there is no test block.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include ..\..\..\..\src\AhfBoot.ahk
#Include ..\..\..\..\src\tray\Tray.ahk

RoleRegistry.Register("tray", Tray)
AhfMain()
