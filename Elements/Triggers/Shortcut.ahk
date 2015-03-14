iniAllTriggers.="Shortcut|" ;Add this trigger to list of all triggers on initialisation

getParametersTriggerShortcut()
{
	global
	parametersToEdit:=["Label|" lang("Path of the Shortcut"),"NewFile|" A_Desktop "\" lang("Shortcut") " " FlowName ".lnk |ShortCutPath|" lang("Set_the_Shortcut_path") "|*.lnk","CheckBox|1|RemoveShortcutOnDisabling|" lang("Remove_shortcut_when_disabling")]
	
	
	return parametersToEdit
}

getNameTriggerShortcut()
{
	return lang("Shortcut")
}
getCategoryTriggerShortcut()
{
	return lang("User_interaction")
}

EnableTriggerShortcut(ID)
{
	global
	
	FileCreateShortcut,%A_ScriptFullPath%,% %id%ShortCutPath,,RunFlow "%ThisFlowFolder%\%ThisFlowFilename%.ini"
	;MsgBox,,,FileCreateShortcut,%A_ScriptFullPath%,% %id%ShortCutPath,,RunFlow "%ThisFlowFolder%\%ThisFlowFilename%"
	
	
}

DisableTriggerShortcut(ID)
{
	if %id%RemoveShortcutOnDisabling=1
		FileDelete,% %id%ShortCutPath
	
	
	
}

GenerateNameTriggerShortcut(ID)
{
	return lang("Shortcut") ": " GUISettingsOfElement%ID%ShortCutPath
	
}