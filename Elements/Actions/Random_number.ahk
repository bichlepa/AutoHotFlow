iniAllActions.="Random_number|" ;Add this action to list of all actions on initialisation

runActionRandom_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempmin
	local tempmax
	local result
	

	tempmin:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%MinValue)

	tempmax:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%MaxValue)
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	if tempmin is number
	{
		if tempmax is number
		{
			Random,result,tempmin,tempmax
			v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	
	return
}
getNameActionRandom_number()
{
	return lang("Random_number")
}
getCategoryActionRandom_number()
{
	return lang("Variable")
}

getParametersActionRandom_number()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Minimum value"),"Text|0|MinValue","Label| " lang("Maximum value"),"Text|100|MaxValue"]
	
	return parametersToEdit
}

GenerateNameActionRandom_number(ID)
{
	global
	
	return % lang("Random_number") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}