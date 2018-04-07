
;this is the menu on top of the main window
;Help! I want that the menu are renamed when the language changes.
initializeMenuBar()
{
	global
	;~ try menu,MyMenu,deleteall
	
	Menu, MyMenu,add,% lang("Save"),ui_Menu_save
	Menu, MyMenu,add,% lang("Run"),ui_Menu_MenuStart
	Menu, MyMenu,add,% lang("Stop"),ui_Menu_MenuStop
	Menu, MyMenu,add,%  lang("Enable"),ui_Menu_Enable
	Menu, EditMenu,add,% "↶ " lang("Undo"),ui_Menu_Undo
	Menu, EditMenu,add,% "↷ " lang("Redo"),ui_Menu_Redo
	Menu, MyMenu,add,% lang("Edit"),:EditMenu
	Menu, MyMenu,add,% lang("Settings"),ui_Menu_Settings
	Menu, MyMenu,add,% lang("Exit"),Exit

	Gui, Maingui:menu, MyMenu
}

SetTimer, ui_Menu_CheckLoop, 10

goto,überspringendsfasdg



ui_Menu_save:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
saveFlow(FlowID)
return




ui_Menu_MenuStart:

executeFlow(FlowID)

return

ui_Menu_MenuStop:
StopFlow(FlowID)
return

ui_Menu_Enable:
enableToggleFlow(FlowID)
return

ui_Menu_Undo:
gosub, ctrl_z
return

ui_Menu_Redo:
gosub, ctrl_y
return


ui_Menu_Settings:
if CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
{
	ui_ActionWhenMainGUIDisabled()
	return
}
ui_SettingsOwFLow()
return

ui_Menu_CheckLoop:

EnterCriticalSection(_cs.flows)

if (menu_bar_IsEnabled != FlowObj.enabled)
{
	if (FlowObj.enabled = True)
	{
		menu_bar_IsEnabled := True
		try Menu, MyMenu,rename,% lang("Enable"),% lang("Disable")
	}
	else if (FlowObj.enabled = false)
	{
		menu_bar_IsEnabled := False
		try Menu, MyMenu,rename,% lang("Disable"),% lang("Enable")
	}
	
}
LeaveCriticalSection(_cs.flows)

return


überspringendsfasdg:
sleep,1