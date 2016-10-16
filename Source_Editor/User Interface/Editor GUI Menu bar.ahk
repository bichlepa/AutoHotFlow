
;this is the menu on top of the main window
;Help! I want that the menu are renamed when the language changes.
initializeMenuBar()
{
	global
	;~ try menu,MyMenu,deleteall
	
	Menu, MyMenu,add,% lang("Save"),ui_Menu_save
	Menu, MyMenu,add,% lang("Run"),ui_Menu_MenuStart
	Menu, MyMenu,add,% lang("Enable"),ui_Menu_Enable
	Menu, MyMenu,add,% lang("Settings"),ui_Menu_Settings
	Menu, MyMenu,add,% lang("Exit"),Exit

	Gui, Maingui:menu, MyMenu
}
goto,überspringendsfasdg



ui_Menu_save:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
API_Main_saveFlow(FlowID)
return




ui_Menu_MenuStart:

if (nowRunning=true)
{
	API_Main_StopFlow(FlowID)
}
else
{
	API_Main_TriggerFlow(FlowID, "User")
}

return




ui_Menu_Enable:
API_Main_enableToggleFlow(FlowID)
return

ui_Menu_Settings:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
ui_SettingsOwFLow()
return



überspringendsfasdg:
sleep,1