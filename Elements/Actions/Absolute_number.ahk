iniAllActions.="Absolute_number|" ;Add this action to list of all actions on initialisation

runActionAbsolute_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if temp is number
	{
		v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),abs(temp))
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	
	return
}
getNameActionAbsolute_number()
{
	return lang("Absolute_number")
}
getCategoryActionAbsolute_number()
{
	return lang("Variable")
}

getParametersActionAbsolute_number()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Number"),"Radio|2|expression|" lang("This is a number") ";" lang("This is a variable name or expression") ,"Text|-2|VarValue"]
	
	return parametersToEdit
}

GenerateNameActionAbsolute_number(ID)
{
	global
	
	return % lang("Absolute_number") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

showHelpForActionAbsolute_number(ID)
{
	
	
}