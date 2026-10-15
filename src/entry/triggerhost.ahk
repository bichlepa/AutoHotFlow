#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046): only the product manager (src/entry/manager.ahk) keeps its icon.
#NoTrayIcon

; Entry script of the role triggerhost (doc/ARCHITECTURE.md D0012, E0041). Placeholder until the trigger host is written (WI-0014). Includes the `trigger` classes.
; The supervisor starts it with --role=triggerhost ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\core\PlaceholderRole.ahk
#Include generated\Elements_triggerhost.ahk

RoleRegistry.Register("triggerhost", PlaceholderRole)
AhfMain()
