iniAllActions.="Set_file_time|" ;Add this action to list of all actions on initialisation

runActionSet_file_time(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVar:=v_replaceVariables(InstanceID,ThreadID,%ElementID%time,"Date")
	local temp
	
	if tempVar=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Places after comma is not a date.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a date.",lang("Input value")))
		return
	}

	if %ElementID%TimeType=1
		tempOptions:="M"
	else if %ElementID%TimeType=2
		tempOptions:="C"
	else if %ElementID%TimeType=3
		tempOptions:="A"
		
	
	;MsgBox %tempVar%
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	FileSetTime,%tempVar%,% tempPath,%tempOptions%
	
	if ErrorLevel
	{
		if not fileexist(tempPath)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' does not exist")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' does not exist",tempPath))
			return
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' could not be read")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' could not be read",tempPath))
			return
		}
	}	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionSet_file_time()
{
	return lang("Set_file_time")
}
getCategoryActionSet_file_time()
{
	return lang("Files")
}

getParametersActionSet_file_time()
{
	global
	
	parametersToEdit:=["Label|" lang("New time") " (" lang("Date format") ")","Text||time","Label|" lang("Select file"),"File||file|" lang("Select a file") "|8","Label|" lang("Which time"),"Radio|1|TimeType|" lang("Modification time") ";" lang("Creation time") ";" lang("Last access time"),"Label|" lang("Options"),"Radio|1|OperateOnWhat|" lang("Operate on files") ";" lang("Operate on files and folders") ";" lang("Operate on folders"),"Checkbox|0|Recurse|" lang("Recurse subfolders into")]
	return parametersToEdit
}

GenerateNameActionSet_file_time(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Set_file_time") " " GUISettingsOfElement%ID%file
	
}

CheckSettingsActionSet_file_time(ID)
{
	
	
}
