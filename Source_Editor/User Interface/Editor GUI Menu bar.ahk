
;this is the menu on top of the main window
;TODO Rename menu when the language changes.
initializeMenuBar()
{
	global
	
	; create menu elements
	Menu, MyMenu,add,% lang("Save #verb"),ui_Menu_save
	Menu, MyMenu,add,% lang("Run #verb"),ui_Menu_MenuStart
	Menu, MyMenu,add,% lang("Stop #verb"),ui_Menu_MenuStop
	Menu, MyMenu,add,%  lang("Enable"),ui_Menu_Enable
	Menu, EditMenu,add,% "↶ " lang("Undo"),ui_Menu_Undo
	Menu, EditMenu,add,% "↷ " lang("Redo"),ui_Menu_Redo
	Menu, MyMenu,add,% lang("Edit #verb"),:EditMenu
	Menu, MyMenu,add,% lang("Settings"),ui_Menu_Settings
	Menu, MyMenu,add,% lang("Exit #verb"),Exit

	; show them in the main gui
	Gui, Maingui:menu, MyMenu
	
	; set timer which continuously updates the menu
	SetTimer, ui_Menu_CheckLoop, 10	
}



; user wants to save
ui_Menu_save()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	saveFlow(FlowID)
}

; user wants to start flow
ui_Menu_MenuStart()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	executeFlow(FlowID)
}

; user wants to stop flow
ui_Menu_MenuStop()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	StopFlow(FlowID)
}

; user wants to enable or disable flow
ui_Menu_Enable()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	enableToggleFlow(FlowID)
}

; user wants to undo a change
ui_Menu_Undo()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	; save as if user presses the hotkey
	key_ctrl_z()
}

; user wants to redo a change
ui_Menu_Redo()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	; save as if user presses the hotkey
	key_ctrl_y()
}

; user wants to change flow settings
ui_Menu_Settings()
{
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	; open flow settings
	ui_SettingsOfFlow()
}

; regular check of the flow state. Depending on that we will update the text in the menu
ui_Menu_CheckLoop()
{
	static menu_bar_IsEnabled

	; get information whether flow is enabled
	tempEnabled := _getFlowProperty(FlowID, "enabled")

	; check whether something changed
	if (menu_bar_IsEnabled != tempEnabled)
	{
		; something changed, update the label of the menu element
		if (tempEnabled = True)
		{
			menu_bar_IsEnabled := True
			try Menu, MyMenu,rename,% lang("Enable"),% lang("Disable")
		}
		else if (tempEnabled = false)
		{
			menu_bar_IsEnabled := False
			try Menu, MyMenu,rename,% lang("Disable"),% lang("Enable")
		}
		
	}
}

