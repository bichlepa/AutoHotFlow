iniAllConditions.="Variable_is_empty|" ;Add this condition to list of all conditions on initialisation

runConditionVariable_is_empty(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	local Varname:=v_replaceVariables(InstanceID,%ElementID%Varname)
	local VarContent:=v_getVariable(InstanceID,Varname)
	;MsgBox "%VarContent%"
	if (VarContent="")
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"yes")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"no")
}


getParametersConditionVariable_is_empty()
{
	
	parametersToEdit:=["Label|" lang("Variable_is_empty"),"Text|VarName|Varname"]
	
	return parametersToEdit
}

getNameConditionVariable_is_empty()
{
	return lang("Variable_is_empty")
}
getCategoryConditionVariable_is_empty()
{
	return lang("Variable")
}

GenerateNameConditionVariable_is_empty(ID)
{
	return lang("Variable_is_empty") ": " GUISettingsOfElement%ID%Varname
	
}