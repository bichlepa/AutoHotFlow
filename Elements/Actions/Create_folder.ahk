iniAllActions.="Create_folder|" ;Add this action to list of all actions on initialisation

runActionCreate_folder(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	FileCreateDir,% tempPath
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionCreate_folder()
{
	return lang("Create_folder")
}
getCategoryActionCreate_folder()
{
	return lang("Files")
}

getParametersActionCreate_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Folder path"),"Folder||folder|" lang("Select a folder") "|3"]
	return parametersToEdit
}

GenerateNameActionCreate_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Create_folder") " " GUISettingsOfElement%ID%folder 
	
}

CheckSettingsActionCreate_folder(ID)
{
	
	
}
