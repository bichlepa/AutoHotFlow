iniAllActions.="Get_file_attributes|" ;Add this action to list of all actions on initialisation

runActionGet_file_attributes(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempattr
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	if tempPath=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File path not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File path")))
		return
	}
	
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output variable name '%1%'",varname)) )
		return
	}
	
	
	if not fileexist(tempPath)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' does not exist.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' does not exist",tempPath))
		return
	}
	
	FileGetAttrib,tempattr,% tempPath
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get file attributes of file '" tempPath "'")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get file attributes of file '%1%'",tempPath))
		return
	}
	
	v_SetVariable(InstanceID,ThreadID,varname,tempattr)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionGet_file_attributes()
{
	return lang("Get_file_attributes")
}
getCategoryActionGet_file_attributes()
{
	return lang("Files")
}

getParametersActionGet_file_attributes()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "FileAttributes", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path"), options: 8})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})

	return parametersToEdit
}

GenerateNameActionGet_file_attributes(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Get_file_attributes") " " GUISettingsOfElement%ID%file
	
}

CheckSettingsActionGet_file_attributes(ID)
{
	
	
}
