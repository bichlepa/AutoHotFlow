iniAllConditions.="File_exists|" ;Add this condition to list of all conditions on initialisation

runConditionFile_exists(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	
	IfExist, % tempPath
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	else 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
	
	 
	
}

stopConditionFile_exists(ID)
{
	
	return
}


getParametersConditionFile_exists()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("File pattern")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})

	return parametersToEdit
}

getNameConditionFile_exists()
{
	return lang("File or folder exists")
}

getCategoryConditionFile_exists()
{
	return lang("Files")
}

GenerateNameConditionFile_exists(ID)
{
	return lang("File or folder exists") ": " GUISettingsOfElement%ID%file
	
}