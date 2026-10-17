#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Entry script of the role storage (doc/ARCHITECTURE.md D0012, E0041). Persists flows, variables and the log (WI-0012). No element classes.
; The supervisor starts it with --role=storage ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\storage\Storage.ahk

RoleRegistry.Register("storage", Storage)
AhfMain()
