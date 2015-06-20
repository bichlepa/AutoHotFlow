iniAllActions.="Move_folder|" ;Add this action to list of all actions on initialisation

runActionMove_folder(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempFrom:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
	local tempTo:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%destFolder)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempFrom)
		tempFrom:=SettingWorkingDir "\" tempFrom
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempTo)
		tempTo:=SettingWorkingDir "\" tempTo
	
	FileMoveDir,% tempFrom,% tempTo,% %ElementID%Overwrite
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionMove_folder()
{
	return lang("Move_folder")
}
getCategoryActionMove_folder()
{
	return lang("Files")
}

getParametersActionMove_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Source folder"),"Folder||folder|" lang("Select a folder") "|","Label|" lang("Destination folder"),"Folder||destFolder|" lang("Select folder") "|","Checkbox|0|Overwrite|" lang("Overwrite existing files")]
	return parametersToEdit
}

GenerateNameActionMove_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Move_folder") " " lang("From %1% to %2%", GUISettingsOfElement%ID%folder,GUISettingsOfElement%ID%destFolder) 
	
}


