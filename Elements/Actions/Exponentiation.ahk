iniAllActions.="Exponentiation|" ;Add this action to list of all actions on initialisation

runActionExponentiation(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempExponentiation
	local tempResult
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	if %ElementID%expressionExponent=1
		tempExponentiation:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Exponent)
	else
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
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Number"),"Radio|2|expression|" lang("This is a number") ";" lang("This is a variable name or expression") ,"Text|3|VarValue","Label| " lang("Exponent"),"Radio|1|expressionExponent|" lang("This is a number") ";" lang("This is a variable name or expression") ,"Text|2|Exponent"]
	
	return parametersToEdit
}

GenerateNameActionExponentiation(ID)
{
	global
	
	return % lang("Exponentiation") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}