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
	parametersToEdit:=Object()
	parmetersToEdit.push({type: "Label", label: lang("Path of the Shortcut")})
	parametersToEdit.push({type: "File", id: "ShortCutPath", default: "%A_Desktop%\" lang("Flow") " " flowSettings.Name ".lnk" , label: lang("Set_the_Shortcut_path"), options: 8, filter: lang("Shortcut") " (*.lnk)"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "CheckBox", id: "RemoveShortcutOnDisabling", default: 1, label: lang("Remove_shortcut_when_disabling")})


	
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