#Requires AutoHotkey v2.0
#SingleInstance Off

; Entry script of the role debug (doc/ARCHITECTURE.md D0012, E0041). The debug window (WI-0028). No element classes.
; The supervisor starts it with --role=debug ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\debugview\DebugView.ahk

RoleRegistry.Register("debug", DebugView)
AhfMain()
