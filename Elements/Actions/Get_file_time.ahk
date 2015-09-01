iniAllActions.="Get_file_time|" ;Add this action to list of all actions on initialisation

runActionGet_file_time(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local temp
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output variable name '%1%'",varname)) )
		return
	}
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	if tempPath=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File path not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File path")))
		return
	}
	
	if not fileexist(tempPath)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' does not exist.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' does not exist",tempPath))
		return
	}
	
	
	if %ElementID%TimeType=1
		tempOptions:="M"
	else if %ElementID%TimeType=2
		tempOptions:="C"
	else if %ElementID%TimeType=3
		tempOptions:="A"
	
	
	FileGetTime,temp,% tempPath,%tempOptions%
	;~ MsgBox %temp% %tempfile% %varname%
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get file time of file '" tempPath "'")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get file time of file '%1%'",tempPath))
		return
	}
	
	v_SetVariable(InstanceID,ThreadID,varname,temp,"Date")
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionGet_file_time()
{
	return lang("Get_file_time")
}
getCategoryActionGet_file_time()
{
	return lang("Files")
}

getParametersActionGet_file_time()
{
	global
	
		parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "FileTime", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8})
	parametersToEdit.push({type: "Label", label: lang("Which time")})
	parametersToEdit.push({type: "Radio", id: "TimeType", default: 1, choices: [lang("Modification time"), lang("Creation time"), lang("Last access time")]})

	return parametersToEdit
}

GenerateNameActionGet_file_time(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Get_file_time") " " GUISettingsOfElement%ID%file
	
}

CheckSettingsActionGet_file_time(ID)
{
	
	
}
