iniAllActions.="Delete_folder|" ;Add this action to list of all actions on initialisation

runActionDelete_folder(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
	
	if %ElementID%ifEmpty
		FileRemoveDir,%temp%
	else
		FileRemoveDir,%temp%,1
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionDelete_folder()
{
	return lang("Delete_folder")
}
getCategoryActionDelete_folder()
{
	return lang("Files")
}

getParametersActionDelete_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Select folder"),"Folder||folder|" lang("Select a folder") "|","Checkbox|0|ifEmpty|" lang("Remove only if the folder is empty")]
	return parametersToEdit
}

GenerateNameActionDelete_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Delete_folder") " " GUISettingsOfElement%ID%folder 
	
}

CheckSettingsActionDelete_folder(ID)
{
	
	
}
