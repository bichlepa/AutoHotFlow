iniAllActions.="Delete_file|" ;Add this action to list of all actions on initialisation

runActionDelete_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=flowSettings.WorkingDir "\" tempPath
	
	if tempPath=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File path not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File path")))
		return
	}
	
	;~ MsgBox %tempPath%
	FileDelete,% tempPath
	temperror:=errorlevel
	
	if a_lasterror
	{
		;~ MsgBox % a_lasterror 
		if temperror
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! " temperror " files not deleted.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% files not deleted",temperror))
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No files deleted.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No files deleted"))
		}
		return
	}
	
	
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("File pattern")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})

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
