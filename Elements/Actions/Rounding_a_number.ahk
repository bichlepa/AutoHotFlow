iniAllActions.="Rounding_a_number|" ;Add this action to list of all actions on initialisation

runActionRounding_a_number(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local tempPlaces
	local tempResult
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input value is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input value")))
		return
	}
	
	tempPlaces:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Places)
	if tempPlaces is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Places after comma is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Places after comma")))
		
		return
	}
	;MsgBox % tempRounding_a_number "|" temp
	
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
	
	v_SetVariable(InstanceID,ThreadID,v_replaceVariables(InstanceID,ThreadID,varname),tempResult)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	

	
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 1.2345, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Places after comma")})
	parametersToEdit.push({type: "Edit", id: "Places", default: 0, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Operation")})
	parametersToEdit.push({type: "Radio", id: "Roundingtype", default: 1, choices: [lang("Round normally"), lang("Round up"), lang("Round down")]})

	return parametersToEdit
}

GenerateNameActionRounding_a_number(ID)
{
	global
	
	return % lang("Rounding_a_number") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}