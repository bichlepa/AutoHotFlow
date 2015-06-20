iniAllActions.="Recycle_file|" ;Add this action to list of all actions on initialisation

runActionRecycle_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	FileRecycle,% tempPath
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionRecycle_file()
{
	return lang("Recycle_file")
}
getCategoryActionRecycle_file()
{
	return lang("Files")
}

getParametersActionRecycle_file()
{
	global
	
	parametersToEdit:=["Label|" lang("Select file"),"File||file|" lang("Select a file") "|"]
	return parametersToEdit
}

GenerateNameActionRecycle_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Recycle_file") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%text
	
}

CheckSettingsActionRecycle_file(ID)
{
	
	
}
