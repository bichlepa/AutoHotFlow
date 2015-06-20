iniAllActions.="Move_file|" ;Add this action to list of all actions on initialisation

runActionMove_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempFrom:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	local tempTo:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%destFile)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempFrom)
		tempFrom:=SettingWorkingDir "\" tempFrom
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempTo)
		tempTo:=SettingWorkingDir "\" tempTo
	
	FileMove,% tempFrom,% tempTo,% %ElementID%Overwrite
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionMove_file()
{
	return lang("Move_file")
}
getCategoryActionMove_file()
{
	return lang("Files")
}

getParametersActionMove_file()
{
	global
	
	parametersToEdit:=["Label|" lang("Source file"),"File||file|" lang("Select a file") "|","Label|" lang("Destination file or folder"),"Folder||destFile|" lang("Select a file or folder") "|","Label|" lang("Overwrite"),"Checkbox|0|Overwrite|" lang("Overwrite existing files")]
	return parametersToEdit
}

GenerateNameActionMove_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Move_file") " " lang("From %1% to %2%", GUISettingsOfElement%ID%file,GUISettingsOfElement%ID%destFile) 
	
}

CheckSettingsActionMove_file(ID)
{
	
	
}
