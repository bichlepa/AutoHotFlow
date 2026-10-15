#Requires AutoHotkey v2.0
#SingleInstance Off

; Entry script of the role editor (doc/ARCHITECTURE.md D0012, E0041). Placeholder until the editor is written. Parses all element classes (not budgeted, E0041).
; The supervisor starts it with --role=editor ... (src/AhfBoot.ahk describes the command line).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\core\PlaceholderRole.ahk
#Include generated\Elements_editor.ahk

RoleRegistry.Register("editor", PlaceholderRole)
AhfMain()
