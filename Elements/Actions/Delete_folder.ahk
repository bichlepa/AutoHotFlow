iniAllActions.="Delete_folder|" ;Add this action to list of all actions on initialisation

runActionDelete_folder(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%folder)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=flowSettings.WorkingDir "\" tempPath
	
	
	
	if %ElementID%ifEmpty
		FileRemoveDir,%tempPath%
	else
		FileRemoveDir,%tempPath%,1
	
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Folder not deleted.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Folder not deleted"))
		return
	}
	
	
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Folder path")})
	parametersToEdit.push({type: "Folder", id: "folder", label: lang("Select a folder")})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "ifEmpty", default: 0, label: lang("Remove only if the folder is empty")})

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
