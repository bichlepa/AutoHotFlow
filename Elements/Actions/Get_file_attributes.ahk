iniAllActions.="Get_file_attributes|" ;Add this action to list of all actions on initialisation

runActionGet_file_attributes(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempattr
	FileGetAttrib,tempattr,% v_replaceVariables(InstanceID,%ElementID%file)
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,v_replaceVariables(InstanceID,%ElementID%varname),tempattr)
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
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
	
	parametersToEdit:=["Label|" lang("Variable name"),"VariableName|FileAttributes|varname","Label|" lang("Select file"),"File||file|" lang("Select a file") "|"]
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
