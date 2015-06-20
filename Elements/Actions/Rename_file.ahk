iniAllActions.="Rename_file|" ;Add this action to list of all actions on initialisation

runActionRename_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempdir
	local tempfilename
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	SplitPath,tempPath,tempfilename,tempdir
	
	if (tempfilename!="" && tempdir!="")
	{
	
		FileMove,%tempdir%\%tempfilename%,% tempdir "\" v_replaceVariables(InstanceID,ThreadID,%ElementID%newName),% %ElementID%Overwrite
		
		if ErrorLevel
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	return
}
getNameActionRename_file()
{
	return lang("Rename_file")
}
getCategoryActionRename_file()
{
	return lang("Files")
}

getParametersActionRename_file()
{
	global
	
	parametersToEdit:=["Label|" lang("File"),"File||file|" lang("Select a file") "|","Label|" lang("New name"),"Text|" lang("Renamed.txt") "|newName","Label|" lang("Overwrite"),"Checkbox|0|Overwrite|" lang("Overwrite existing files")]
	return parametersToEdit
}

GenerateNameActionRename_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Rename_file") " " GUISettingsOfElement%ID%file " " lang("To") " " GUISettingsOfElement%ID%newName 
	
}

CheckSettingsActionRename_file(ID)
{
	
	
}
