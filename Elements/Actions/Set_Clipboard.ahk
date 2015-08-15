iniAllActions.="Set_Clipboard|" ;Add this action to list of all actions on initialisation

runActionSet_Clipboard(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempText
	
	if %ElementID%expression=1
		tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text)
	else
		tempText:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%text)
	
	Clipboard:=tempText
	

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
GetNameActionSet_Clipboard()
{
	return lang("Set Clipboard")
}
GetCategoryActionSet_Clipboard()
{
	return lang("Variable")
}

GetParametersActionSet_Clipboard()
{
	global
	parametersToEdit:=["Label|" lang("Text to set"),"Radio|1|expression|" lang("This is a string") ";" lang("This is a variable name or expression")y,"Text||text"]
	
	return parametersToEdit
}

GenerateNameActionSet_Clipboard(ID)
{
	global
	
	return % lang("Set_Clipboard") " - " GUISettingsOfElement%ID%text
	
}