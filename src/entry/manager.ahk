#Requires AutoHotkey v2.0
#SingleInstance Off

; Entry script of the role manager (doc/ARCHITECTURE.md D0012, E0041). The manager. Stub only (WI-0013). It needs no element classes yet; if the real manager needs the metadata, it loads all classes (accepted, E0041).
; The supervisor starts it with --role=manager ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\manager\StubManager.ahk

RoleRegistry.Register("manager", StubManager)
AhfMain()
