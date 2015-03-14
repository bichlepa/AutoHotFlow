iniAllActions.="Copy_folder|" ;Add this action to list of all actions on initialisation

runActionCopy_folder(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	
	FileCopyDir,% v_replaceVariables(InstanceID,%ElementID%folder),% v_replaceVariables(InstanceID,%ElementID%destFolder),% %ElementID%Overwrite
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionCopy_folder()
{
	return lang("Copy_folder")
}
getCategoryActionCopy_folder()
{
	return lang("Files")
}

getParametersActionCopy_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Source folder"),"Folder||folder|" lang("Select a folder") "|","Label|" lang("Destination folder"),"Folder||destFolder|" lang("Select folder") "|","Checkbox|0|Overwrite|" lang("Overwrite existing files")]
	return parametersToEdit
}

GenerateNameActionCopy_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Copy_folder") " " lang("From %1% to %2%", GUISettingsOfElement%ID%folder,GUISettingsOfElement%ID%destFolder) 
	
}


