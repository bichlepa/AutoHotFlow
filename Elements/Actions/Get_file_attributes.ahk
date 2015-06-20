iniAllActions.="Get_file_attributes|" ;Add this action to list of all actions on initialisation

runActionGet_file_attributes(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempattr
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	FileGetAttrib,tempattr,% tempPath
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%varname),tempattr)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
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
	
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|FileAttributes|varname","Label|" lang("File path"),"File||file|" lang("Select a file") "|"]
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
