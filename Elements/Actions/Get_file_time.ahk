iniAllActions.="Get_file_time|" ;Add this action to list of all actions on initialisation

runActionGet_file_time(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVarName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local tempfile:=v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	local temp
	
	if tempVarName=
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	if %ElementID%TimeType=1
		tempOptions:="M"
	else if %ElementID%TimeType=2
		tempOptions:="C"
	else if %ElementID%TimeType=3
		tempOptions:="A"
		
	
	
	FileGetTime,temp,% tempfile,%tempOptions%
	;~ MsgBox %temp% %tempfile% %tempVarName%
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,ThreadID,tempVarName,temp,"Date")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
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
	
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|FileTime|varname","Label|" lang("File path"),"File||file|" lang("Select a file") "|8","Label|" lang("Which time"),"Radio|1|TimeType|" lang("Modification time") ";" lang("Creation time") ";" lang("Last access time")]
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
