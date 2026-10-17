#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon: the icon of the application belongs to the role tray (E0075).
#NoTrayIcon

; Entry script of the role manager (doc/ARCHITECTURE.md D0012, E0041). The manager (WI-0073). It needs no element classes: whatever needs element metadata is computed by the engine and sent with the answer.
; The supervisor starts it with --role=manager ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\manager\Manager.ahk

RoleRegistry.Register("manager", Manager)
AhfMain()
