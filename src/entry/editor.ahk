#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon yet (E0046): the editor's own icon comes with WI-0091 (REQ-EDT-230); until then this entry hides it.
#NoTrayIcon

; Entry script of the role editor (doc/ARCHITECTURE.md D0012, E0041, WI-0088). The editor shows one flow (PROTOCOL 4.11).
; The supervisor starts it with --role=editor --flow=<flowId> ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code, the element classes of this role (all of them: the editor shows every flow) and the
; code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\editor\Editor.ahk
#Include generated\Elements_editor.ahk

RoleRegistry.Register("editor", Editor)
AhfMain()
