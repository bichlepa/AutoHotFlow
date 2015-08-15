iniAllActions.="Move_file|" ;Add this action to list of all actions on initialisation

runActionMove_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temperror
	
	local tempFrom:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	local tempTo:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%destFile)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempFrom)
		tempFrom:=SettingWorkingDir "\" tempFrom
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempTo)
		tempTo:=SettingWorkingDir "\" tempTo
	
	if tempFrom=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Source file not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Source file")))
		return
	}
	
	
	FileCopy,% tempFrom,% tempTo,% %ElementID%Overwrite
	temperror:=errorlevel
	
	if a_lasterror
	{
		;~ MsgBox % a_lasterror 
		if temperror
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! " temperror " files not moved.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% files not moved",temperror))
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No files moved.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No files moved"))
		}
		return
	}
	
	
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
