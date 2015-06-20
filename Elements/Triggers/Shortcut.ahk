iniAllTriggers.="Shortcut|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerShortcut(ID)
{
	global
	
	local path :=v_replaceVariables(0,0,%id%ShortCutPath) 
	
	FileCreateShortcut,%A_ScriptFullPath%,%path%,,RunFlow "%ThisFlowFolder%\%ThisFlowFilename%.ini"
	
	;~ MsgBox,,, % "FileCreateShortcut," A_ScriptFullPath "," %id%ShortCutPath ",,RunFlow " ThisFlowFolder "\" ThisFlowFilename
	
	
}

DisableTriggerShortcut(ID)
{
	if %id%RemoveShortcutOnDisabling=1
		FileDelete,% %id%ShortCutPath
	
	
	
}

getParametersTriggerShortcut()
{
	global
	parametersToEdit:=["Label|" lang("Path of the Shortcut"),"File|%A_Desktop%\" lang("Flow") " " FlowName ".lnk |ShortCutPath|" lang("Set_the_Shortcut_path") "|8|*.lnk","CheckBox|1|RemoveShortcutOnDisabling|" lang("Remove_shortcut_when_disabling")]
	
	
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



GenerateNameTriggerShortcut(ID)
{
	return lang("Shortcut") ": " GUISettingsOfElement%ID%ShortCutPath
	
}