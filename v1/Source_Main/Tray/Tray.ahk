
; change the tray icon
Menu, tray, Icon, %_ScriptDir%\Icons\mainicon.ico

; create tray menu
if a_iscompiled
{
	; delete default menu if compiled
	Menu, tray, NoStandard
}
else
{
	; if not compiled, add a delimiter
	;Menu, tray, add	
}

; add entry to show manager gui and set it to default (action on double click)
Menu, tray, add, % lang("Show Manager"), onTrayMenuShowManagerGUI
Menu, tray, default, % lang("Show Manager")

; add entry to exit AHF
Menu, tray, add, % lang("Exit #verb"), exit


; disable default tray menu entries
if (not _settings.developing)
	Menu, tray, NoStandard


; Set tooltip of tray icon
Menu, tray, tip, % "AutoHotFlow"

; user wants to open the manager gui 
onTrayMenuShowManagerGUI()
{
	API_Manager_ShowWindow()
}
