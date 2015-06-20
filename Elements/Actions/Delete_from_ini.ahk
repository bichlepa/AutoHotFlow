iniAllActions.="Delete_from_ini|" ;Add this action to list of all actions on initialisation

runActionDelete_from_ini(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	if %ElementID%Action=1 ;Delete a key
	{
		
		IniDelete,% tempPath,% v_replaceVariables(InstanceID,ThreadID,%ElementID%section),% v_replaceVariables(InstanceID,ThreadID,%ElementID%key)
		
	}
	else ;Delete a section
	{
		IniDelete,% tempPath,% v_replaceVariables(InstanceID,ThreadID,%ElementID%section)
		
	}
	
	if errorlevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
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
	
	parametersToEdit:=["Label|" lang("Path of an .ini file"),"File||file|" lang("Select an .ini file") "|8|(*.ini)","Label|" lang("Action"),"Radio|1|Action|" lang("Delete a key") ";" lang("Delete a section"),"Label|" lang("Section"),"Text|section|Section","Label|" lang("Key"),"Text|key|Key" ]
	
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
