iniAllActions.="Delete_file|" ;Add this action to list of all actions on initialisation

runActionDelete_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	;~ MsgBox %tempPath%
	FileDelete,% tempPath
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionDelete_file()
{
	return lang("Delete_file")
}
getCategoryActionDelete_file()
{
	return lang("Files")
}

getParametersActionDelete_file()
{
	global
	
	parametersToEdit:=["Label|" lang("File pattern"),"File||file|" lang("Select a file") "|"]
	return parametersToEdit
}

GenerateNameActionDelete_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Delete_file") " " GUISettingsOfElement%ID%file 
	
}

CheckSettingsActionDelete_file(ID)
{
	
	
}
