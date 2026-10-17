#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Entry script of the role worker (doc/ARCHITECTURE.md D0012, E0041). Runs the elements of mode `worker` in a process of its own (WI-0011).
; The supervisor starts it with --role=worker ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\worker\Worker.ahk
#Include generated\Elements_worker.ahk

RoleRegistry.Register("worker", Worker)
AhfMain()
