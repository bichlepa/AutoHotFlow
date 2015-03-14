iniAllActions.="Create_folder|" ;Add this action to list of all actions on initialisation

runActionCreate_folder(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	FileCreateDir,% v_replaceVariables(InstanceID,%ElementID%folder)
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionCreate_folder()
{
	return lang("Create_folder")
}
getCategoryActionCreate_folder()
{
	return lang("Files")
}

getParametersActionCreate_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Select folder"),"Folder||folder|" lang("Select a folder") "|3"]
	return parametersToEdit
}

GenerateNameActionCreate_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Create_folder") " " GUISettingsOfElement%ID%folder 
	
}

CheckSettingsActionCreate_folder(ID)
{
	
	
}
