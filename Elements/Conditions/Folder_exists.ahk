iniAllConditions.="Folder_exists|" ;Add this condition to list of all conditions on initialisation

runConditionFolder_exists(InstanceID,ElementID,ElementIDInInstance)
{
	global
	local tempFolder:=v_replaceVariables(InstanceID,%ElementID%folder)
	
	
	IfExist, % tempFolder
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"yes")
	else 
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"no")
	
	 
	
}

stopConditionFolder_exists(ID)
{
	
	return
}


getParametersConditionFolder_exists()
{
	
	parametersToEdit:=["Label|" lang("Select folder"),"Folder||folder|" lang("Select a folder") "|"]
	
	return parametersToEdit
}

getNameConditionFolder_exists()
{
	return lang("Folder_exists")
}

getCategoryConditionFolder_exists()
{
	return lang("Files")
}

GenerateNameConditionFolder_exists(ID)
{
	return lang("Folder_exists") ": " GUISettingsOfElement%ID%folder
	
}