iniAllActions.="Delete_from_ini|" ;Add this action to list of all actions on initialisation

runActionDelete_from_ini(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	local tempsection:=v_replaceVariables(InstanceID,ThreadID,%ElementID%section)
	local tempkey
	
	
	if %ElementID%Action=1 ;Delete a key
	{
		tempkey:=v_replaceVariables(InstanceID,ThreadID,%ElementID%key)
		IniDelete,% tempPath,% tempsection,% tempkey
		if errorlevel
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Not deleted from ini.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Not deleted from ini"))
			return
		}
	
	}
	else ;Delete a section
	{
		IniDelete,% tempPath,% tempsection
		if errorlevel
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Not deleted from ini.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Not deleted from ini"))
			return
		}
	}
	
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	return
}
getNameActionDelete_from_ini()
{
	return lang("Delete_from_ini")
}
getCategoryActionDelete_from_ini()
{
	return lang("Files")
}

getParametersActionDelete_from_ini()
{
	global
		parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Path of an .ini file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "Action", default: 1, choices: [lang("Delete a key"), lang("Delete a section")]})
	parametersToEdit.push({type: "Label", label: lang("Section")})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionDelete_from_ini(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	if GUISettingsOfElement%ID%Action1
		return lang("Delete_from_ini") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%Section " - " GUISettingsOfElement%ID%key
	else
		return lang("Delete_from_ini") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%Section
	
}

CheckSettingsActionDelete_from_ini(ID)
{
	if (GUISettingsOfElement%ID%Action1 != 1)
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%Key
	}
	else
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%Key
	}
	
	
}
