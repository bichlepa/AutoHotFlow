iniAllActions.="Delete_file|" ;Add this action to list of all actions on initialisation

runActionDelete_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	FileDelete,% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionDelete_file()
{
	return lang("Delete_file")
}
getCategoryActionDelete_file()
{
	return lang("Files")
}

getParametersActionDelete_file()
{
	global
	
	parametersToEdit:=["Label|" lang("Select file"),"File||file|" lang("Select a file") "|"]
	return parametersToEdit
}

GenerateNameActionDelete_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Delete_file") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%text
	
}

CheckSettingsActionDelete_file(ID)
{
	
	
}
