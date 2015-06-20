iniAllActions.="Exponentiation|" ;Add this action to list of all actions on initialisation

runActionExponentiation(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempExponentiation
	local tempResult
	
	
	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	
	tempExponentiation:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Exponent)
	;MsgBox % tempExponentiation "|" temp
	if temp is number
	{
		if tempExponentiation is number
		{
			tempResult:=temp**tempExponentiation
			v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname),tempResult)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	
	return
}
getNameActionExponentiation()
{
	return lang("Exponentiation")
}
getCategoryActionExponentiation()
{
	return lang("Variable")
}

getParametersActionExponentiation()
{
	global
	parametersToEdit:=["Label|" lang("Output variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Input number"),"Text|3|VarValue","Label| " lang("Exponent") ,"Text|2|Exponent"]
	
	return parametersToEdit
}

GenerateNameActionExponentiation(ID)
{
	global
	
	return % lang("Exponentiation") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}