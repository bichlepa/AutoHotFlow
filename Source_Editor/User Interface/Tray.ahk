
; disable default tooltip controls if AHF is compiled
if (not _getSettings("developing"))
{
	menu, tray, NoStandard
}

; initialize tray menu
;TODO I want that the menu will be renamed when the language changes.
initializeTrayBar()
{
	global
	try menu, tray, deleteall
	
	menu, tray, add,  tray_show
	menu, tray, rename, tray_show, % lang("Show #verb")

	menu, tray, add, tray_start
	menu, tray, rename, tray_start, % lang("Run #verb")

	menu, tray, add, tray_enable
	menu, tray, rename, tray_enable, % lang("Enable")

	menu, tray, add, Exit
	menu, tray, rename, Exit, % lang("Exit #verb")

	menu, tray, icon, %_ScriptDir%\Icons\disabled.ico
	
	menu, tray, tip, % lang("Flow") ": " _getFlowProperty(FlowID, "name")
}

; react if user clicks on "show" entry
tray_show()
{
	EditGUIshow()
}

; react if user clicks on "start" entry
tray_start()
{
	executeFlow(FlowID)
}

; react if user clicks on "enable" entry
tray_enable()
{
	enableToggleFlow(FlowID)
}