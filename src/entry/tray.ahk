#Requires AutoHotkey v2.0
#SingleInstance Off
; The icon appears only when the role has built its menu (Tray.Start); a headless role keeps it hidden (E0046, E0075).
#NoTrayIcon

; Entry script of the role tray (doc/ARCHITECTURE.md D0012, E0041, E0075). The tray icon and the tray menu of the application.
; The supervisor starts it with --role=tray ... (src/AhfBoot.ahk describes the command line). No element classes.
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\tray\Tray.ahk

RoleRegistry.Register("tray", Tray)
AhfMain()
