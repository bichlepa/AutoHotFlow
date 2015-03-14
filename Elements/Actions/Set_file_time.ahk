iniAllActions.="Set_file_time|" ;Add this action to list of all actions on initialisation

runActionSet_file_time(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVar:=v_replaceVariables(InstanceID,%ElementID%time,"Date")
	local temp
	
	if tempVar=
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")

	if %ElementID%TimeType=1
		tempOptions:="M"
	else if %ElementID%TimeType=2
		tempOptions:="C"
	else if %ElementID%TimeType=3
		tempOptions:="A"
		
	
	;MsgBox %tempVar%
	FileSetTime,%tempVar%,% v_replaceVariables(InstanceID,%ElementID%file),%tempOptions%
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,tempVarName,temp,"Date")
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	}
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
	
	parametersToEdit:=["Label|" lang("New time") " (" lang("Date format") ")","Text||time","Label|" lang("Select file"),"File||file|" lang("Select a file") "|8","Label|" lang("Whitch time"),"Radio|1|TimeType|" lang("Modification time") ";" lang("Creation time") ";" lang("Last access time")]
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
