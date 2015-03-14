iniAllActions.="Get_file_size|" ;Add this action to list of all actions on initialisation

runActionGet_file_size(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVarName:=v_replaceVariables(InstanceID,%ElementID%varname)
	local temp
	
	if tempVarName=
	{
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
		return
	}

	if %ElementID%Unit=2
		tempOptions:="K"
	else if %ElementID%Unit=3
		tempOptions:="M"
		
	
	
	FileGetSize,temp,% v_replaceVariables(InstanceID,%ElementID%file),%tempOptions%
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,tempVarName,temp)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
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
	
	parametersToEdit:=["Label|" lang("Variable name"),"VariableName|NewSize|varname","Label|" lang("Select file"),"File||file|" lang("Select a file") "|8","Label|" lang("Unit"),"Radio|1|Unit|" lang("Bytes") ";" lang("Kilobytes") ";" lang("Megabytes")]
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
