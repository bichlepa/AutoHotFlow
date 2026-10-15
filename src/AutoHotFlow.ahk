#Requires AutoHotkey v2.0
#SingleInstance Off

; Entry of the supervisor, the file the user starts (doc/ARCHITECTURE.md D0012, E0041). The other roles have an entry script
; of their own in src\entry\<role>.ahk; the supervisor starts them from there (Children.EntryScript). This file
; includes the shared boot code (AhfBoot.ahk) and the supervisor, no element class and no other role.
;   AutoHotkey64.exe src\AutoHotFlow.ahk [--session=<id>] [--data=<dir>] [--start=<role>[:<flow>],...] (Supervisor.ahk)
#Include AhfBoot.ahk
#Include supervisor\Supervisor.ahk

AhfMain((opts) => Supervisor.Run(opts))
