#Requires AutoHotkey v2.0
#SingleInstance Off
; The directive hides the icon the script would get by default (E0046, E0075); the editor's own icon is shown by its code,
; EditorTray.Start (REQ-EDT-230, WI-0091).
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
