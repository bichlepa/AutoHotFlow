iniAllActions.="Write_to_ini|" ;Add this action to list of all actions on initialisation

runActionWrite_to_ini(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	
	local tempText
	

	
	
	
	
	
	IniWrite,% v_replaceVariables(InstanceID,%ElementID%Value),% v_replaceVariables(InstanceID,%ElementID%file),% v_replaceVariables(InstanceID,%ElementID%section),% v_replaceVariables(InstanceID,%ElementID%key)
	
	if errorlevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	
	
	
	
	
	return
}
getNameActionWrite_to_ini()
{
	return lang("Write_to_ini")
}
getCategoryActionWrite_to_ini()
{
	return lang("Files")
}

getParametersActionWrite_to_ini()
{
	global
	
	parametersToEdit:=["Label|" lang("Value"),"VariableName|value|Value","Label|" lang("Select an .ini file"),"File||file|" lang("Select an .ini file") "|8|(*.ini)","Label|" lang("Section"),"Text|section|Section","Label|" lang("Key"),"Text|key|Key"]
	return parametersToEdit
}

GenerateNameActionWrite_to_ini(ID)
{
	global
	;MsgBox % %ID%text_to_show
	

	return lang("Write_to_ini") " " GUISettingsOfElement%ID%Value ": " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%Section " - " GUISettingsOfElement%ID%key

	
}

CheckSettingsActionWrite_to_ini(ID)
{
	
	
	
}
