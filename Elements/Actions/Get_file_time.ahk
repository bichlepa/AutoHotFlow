iniAllActions.="Get_file_time|" ;Add this action to list of all actions on initialisation

runActionGet_file_time(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVarName:=v_replaceVariables(InstanceID,%ElementID%varname)
	local temp
	
	if tempVarName=
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")

	if %ElementID%TimeType=1
		tempOptions:="M"
	else if %ElementID%TimeType=2
		tempOptions:="C"
	else if %ElementID%TimeType=3
		tempOptions:="A"
		
	
	
	FileGetTime,temp,% v_replaceVariables(InstanceID,%ElementID%file),%tempOptions%
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,tempVarName,temp,"Date")
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
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
	
	parametersToEdit:=["Label|" lang("Variable name"),"VariableName|FileTime|varname","Label|" lang("Select file"),"File||file|" lang("Select a file") "|8","Label|" lang("Whitch time"),"Radio|1|TimeType|" lang("Modification time") ";" lang("Creation time") ";" lang("Last access time")]
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
