iniAllConditions.="File_exists|" ;Add this condition to list of all conditions on initialisation

runConditionFile_exists(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local tempfile:=v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	
	IfExist, % tempfile
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
	
	parametersToEdit:=["Label|" lang("Select file"),"File||file|" lang("Select a file") "|"]
	
	return parametersToEdit
}

getNameConditionFile_exists()
{
	return lang("File_exists")
}

getCategoryConditionFile_exists()
{
	return lang("Files")
}

GenerateNameConditionFile_exists(ID)
{
	return lang("File_exists") ": " GUISettingsOfElement%ID%file
	
}