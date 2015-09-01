iniAllActions.="Exponentiation|" ;Add this action to list of all actions on initialisation

runActionExponentiation(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	local tempExponentiation:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Exponent)
	local tempResult
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	
	
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output variable name '%1%'",varname)) )
		return
	}
	
	;MsgBox % tempExponentiation "|" temp
	
	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input number " temp " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input number '%1%'",temp)) )
		return
	}
	
	if tempExponentiation is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input exponent " tempExponentiation " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Input exponent '%1%'",tempExponentiation)) )
		return
	}
	
	
	tempResult:=temp**tempExponentiation
	v_SetVariable(InstanceID,ThreadID,varname,tempResult)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input number")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: 3, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Exponent")})
	parametersToEdit.push({type: "Edit", id: "Exponent", default: 2, content: "Expression", WarnIfEmpty: true})

	
	return parametersToEdit
}

GenerateNameActionExponentiation(ID)
{
	global
	
	return % lang("Exponentiation") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}