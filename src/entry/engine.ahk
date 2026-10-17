#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon (E0046, E0075): the icon of the application belongs to the role tray (src/tray/Tray.ahk).
#NoTrayIcon

; Entry script of the role engine (doc/ARCHITECTURE.md D0012, E0041). Runs the flows. All element classes: the conversion of the parameters needs the metadata of every class, `Run`/`Stop` are used for `inline` (E0041).
; The supervisor starts it with --role=engine ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\engine\Engine.ahk
#Include generated\Elements_engine.ahk

RoleRegistry.Register("engine", Engine)
AhfMain()
