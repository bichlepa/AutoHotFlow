#Requires AutoHotkey v2.0
#SingleInstance Off

; Probe for tests/integration/test_entry.py (E0046): includes the boot file like every entry and prints the tray icon state.
#Include ..\..\..\src\AhfBoot.ahk

FileAppend("A_IconHidden=" A_IconHidden "`n", "*", "UTF-8-RAW")
ExitApp(0)
