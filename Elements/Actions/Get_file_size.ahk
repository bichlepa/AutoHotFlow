iniAllActions.="Get_file_size|" ;Add this action to list of all actions on initialisation

runActionGet_file_size(InstanceID,ThreadID,ElementID,ElementIDInInstance)
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
		tempPath:=flowSettings.WorkingDir "\" tempPath
	
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
	
	
	if %ElementID%Unit=2
		tempOptions:="K"
	else if %ElementID%Unit=3
		tempOptions:="M"
	
	
	FileGetSize,temp,% tempPath,%tempOptions%
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get file size of file '" tempPath "'")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get file size of file '%1%'",tempPath))
		return
	}
	
	v_SetVariable(InstanceID,ThreadID,varname,temp)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionGet_file_size()
{
	return lang("Get_file_size")
}
getCategoryActionGet_file_size()
{
	return lang("Files")
}

getParametersActionGet_file_size()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "NewSize", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8})
	parametersToEdit.push({type: "Label", label: lang("Unit")})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 1, choices: [lang("Bytes"), lang("Kilobytes"), lang("Megabytes")]})

	return parametersToEdit
}

GenerateNameActionGet_file_size(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Get_file_size") " " GUISettingsOfElement%ID%file
	
}

CheckSettingsActionGet_file_size(ID)
{
	
	
}
