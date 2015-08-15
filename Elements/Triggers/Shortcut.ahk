iniAllTriggers.="Shortcut|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerShortcut(ElementID)
{
	global
	
	local path :=v_replaceVariables(0,0,%ElementID%ShortCutPath) 
	
	FileCreateShortcut,%A_ScriptFullPath%,%path%,,RunFlow "%ThisFlowFolder%\%ThisFlowFilename%.ini" %ElementID%
	
	;~ MsgBox,,, % "FileCreateShortcut," A_ScriptFullPath "," %id%ShortCutPath ",,RunFlow " ThisFlowFolder "\" ThisFlowFilename
	
	
}

DisableTriggerShortcut(ElementID)
{
	global
	if %ElementID%RemoveShortcutOnDisabling=1
	{
		local path :=v_replaceVariables(0,0,%ElementID%ShortCutPath) 
		FileDelete,% path
	}
	
	
}

getParametersTriggerShortcut()
{
	global
	parametersToEdit:=["Label|" lang("Path of the Shortcut"),"File|%A_Desktop%\" lang("Flow") " " FlowName ".lnk |ShortCutPath|" lang("Set_the_Shortcut_path") "|8|*.lnk","Label|" lang("Options"),"CheckBox|1|RemoveShortcutOnDisabling|" lang("Remove_shortcut_when_disabling")]
	
	
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