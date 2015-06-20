iniAllActions.="Write_to_ini|" ;Add this action to list of all actions on initialisation

runActionWrite_to_ini(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	
	local tempText
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	
	
	
	
	IniWrite,% v_replaceVariables(InstanceID,ThreadID,%ElementID%Value),% tempPath,% v_replaceVariables(InstanceID,ThreadID,%ElementID%section),% v_replaceVariables(InstanceID,ThreadID,%ElementID%key)
	
	if errorlevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	
	
	
	return
}
getNameActionWrite_to_ini()
{
	return lang("Write_to_ini")
}
getCategoryActionWrite_to_ini()
{
	return lang("Files")
}

getParametersActionWrite_to_ini()
{
	global
	
	parametersToEdit:=["Label|" lang("Value"),"VariableName|value|Value","Label|" lang("Select an .ini file"),"File||file|" lang("Select an .ini file") "|8|(*.ini)","Label|" lang("Section"),"Text|section|Section","Label|" lang("Key"),"Text|key|Key"]
	return parametersToEdit
}

GenerateNameActionWrite_to_ini(ID)
{
	global
	;MsgBox % %ID%text_to_show
	

	return lang("Write_to_ini") " " GUISettingsOfElement%ID%Value ": " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%Section " - " GUISettingsOfElement%ID%key

	
}

CheckSettingsActionWrite_to_ini(ID)
{
	
	
	
}
