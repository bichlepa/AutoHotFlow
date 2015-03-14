iniAllActions.="Rename_folder|" ;Add this action to list of all actions on initialisation

runActionRename_folder(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local temppos
	local tempoldname
	local tempfolder:=v_replaceVariables(InstanceID,%ElementID%folder)
	StringGetPos,temppos,tempfolder,\,R
	StringTrimLeft,tempoldname,tempfolder,% temppos +1
	StringLeft,tempfolder,tempfolder,% temppos
	
	FileMoveDir,% tempfolder "\" tempoldname ,% tempfolder "\" v_replaceVariables(InstanceID,%ElementID%newName),R
	
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"exception")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionRename_folder()
{
	return lang("Rename_folder")
}
getCategoryActionRename_folder()
{
	return lang("Files")
}

getParametersActionRename_folder()
{
	global
	
	parametersToEdit:=["Label|" lang("Folder"),"Folder||folder|" lang("Select a folder") "|","Label|" lang("New name"),"Text|" lang("Unnamed") "|newName"]
	return parametersToEdit
}

GenerateNameActionRename_folder(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Rename_folder") " " lang("From %1% to %2%", GUISettingsOfElement%ID%folder,GUISettingsOfElement%ID%destFolder) 
	
}


