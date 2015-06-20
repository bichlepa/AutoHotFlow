iniAllActions.="Rename_folder|" ;Add this action to list of all actions on initialisation

runActionRename_folder(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temppos
	local tempoldname
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	local tempPath:=v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
	StringGetPos,temppos,tempPath,\,R
	StringTrimLeft,tempoldname,tempPath,% temppos +1
	StringLeft,tempPath,tempPath,% temppos
	
	FileMoveDir,% tempPath "\" tempoldname ,% tempPath "\" v_replaceVariables(InstanceID,ThreadID,%ElementID%newName),R
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionRename_folder()
{
	return lang("Rename_folder")
}
getCategoryActionRename_folder()
{
	return lang("Files")
}

getParametersActionRename_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Folder"),"Folder||folder|" lang("Select a folder") "|","Label|" lang("New name"),"Text|" lang("Unnamed") "|newName"]
	return parametersToEdit
}

GenerateNameActionRename_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Rename_folder") " " lang("From %1% to %2%", GUISettingsOfElement%ID%folder,GUISettingsOfElement%ID%destFolder) 
	
}


