iniAllConditions.="key_is_down|" ;Add this condition to list of all conditions on initialisation

runConditionkey_is_down(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	
	
	
	GetKeyState,tempKeyState,% %ElementID%key
	
	
	if (tempKeyState="d")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	else if (tempKeyState="u")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
	else
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Couldn't get key state.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't get key state"))
		return
	}
	 
	
}

stopConditionKey_is_down(ID)
{
	
	return
}


getParametersConditionkey_is_down()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Key name")})
	parametersToEdit.push({type: "Edit", id: "key", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

getNameConditionKey_is_down()
{
	return lang("key_is_down")
}

getCategoryConditionKey_is_down()
{
	return lang("User_interaction")
}

GenerateNameConditionKey_is_down(ID)
{
	return lang("key_is_down") ": " GUISettingsOfElement%ID%key
	
}