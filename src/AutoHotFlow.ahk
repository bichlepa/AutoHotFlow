#Requires AutoHotkey v2.0
#SingleInstance Off

; Single entry point of every role process (doc/ARCHITEKTUR.md D12). The code is in AhfBoot.ahk (WI-29), so that the
; test entry tests/integration/helpers/AutoHotFlowTest.ahk can run the same code with the test roles added.
;   AutoHotkey64.exe src\AutoHotFlow.ahk --role=<name> --session=<id> --hub=<pipe> --data=<dir> [--flow=<id>] [--hubHwnd=<n>]
#Include AhfBoot.ahk

AhfMain()
