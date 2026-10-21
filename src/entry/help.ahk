#Requires AutoHotkey v2.0
#SingleInstance Off
; No tray icon: the icon of the application belongs to the role tray (E0075).
#NoTrayIcon

; Entry script of the role help (WI-0111, E0098, PROTOCOL 4.12): the help window and its viewers. It needs no element
; classes: the pages are generated HTML files (tools/gen_help.py). The supervisor starts it on demand (cmd.help.show).
; It includes the shared boot code and the code of this role, nothing of another role.
#Include ..\AhfBoot.ahk
#Include ..\help\HelpRole.ahk

RoleRegistry.Register("help", HelpRole)
AhfMain()
