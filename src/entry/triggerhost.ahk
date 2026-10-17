#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Entry script of the role triggerhost (doc/ARCHITECTURE.md D0012, E0041, WI-0061). Includes the `trigger` classes.
; The supervisor starts it with --role=triggerhost ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\triggerhost\TriggerHost.ahk
#Include generated\Elements_triggerhost.ahk

RoleRegistry.Register("triggerhost", TriggerHost)
AhfMain()
