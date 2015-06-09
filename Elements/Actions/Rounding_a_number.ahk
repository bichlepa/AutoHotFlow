iniAllActions.="Rounding_a_number|" ;Add this action to list of all actions on initialisation

runActionRounding_a_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempPlaces
	local tempResult
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	if %ElementID%expressionPlaces=1
		tempPlaces:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Places)
	else
		tempPlaces:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Places)
	;MsgBox % tempRounding_a_number "|" temp
	if temp is number
	{
		if tempPlaces is number
		{
			if %ElementID%roundingtype=1 ;Normal rounding
			{
				tempResult:=round(temp,tempPlaces)
			}
			else if %ElementID%Roundingtype=2 ;Rounding_a_number up
			{
				tempResult:=round(temp,tempPlaces)
				if (tempResult<temp)
				{
					tempResult+=10**(-tempPlaces)
					tempResult:=round(tempResult,tempPlaces)
				}
			}
			else if %ElementID%Roundingtype=3 ;Rounding_a_number down
			{
				tempResult:=round(temp,tempPlaces)
				if (tempResult>temp)
				{
					tempResult-=10**(-tempPlaces)
					tempResult:=round(tempResult,tempPlaces)
				}	
			}
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
getNameActionRounding_a_number()
{
	return lang("Rounding_a_number")
}
getCategoryActionRounding_a_number()
{
	return lang("Variable")
}

getParametersActionRounding_a_number()
{
	global
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|NewVariable|Varname","Label| " lang("Number"),"Radio|2|expression|" lang("This is a number") ";" lang("This is a variable name or expression") ,"Text|1.2345|VarValue","Label| " lang("Places after comma"),"Radio|1|expressionPlaces|" lang("This is a number") ";" lang("This is a variable name or expression") ,"Text|0|Places","Radio|1|Roundingtype|" lang("Round normally") ";" lang("Round up") ";" lang("Round down") ]
	
	return parametersToEdit
}

GenerateNameActionRounding_a_number(ID)
{
	global
	
	return % lang("Rounding_a_number") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}