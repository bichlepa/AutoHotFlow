iniAllActions.="New_variable|" ;Add this action to list of all actions on initialisation

runActionNew_variable(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local Value

	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
		
	if %ElementID%expression=2
		Value:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	else
		Value:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	

	v_SetVariable(InstanceID,ThreadID,Varname,Value)
	
	

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionNew_variable()
{
	return lang("New_variable")
}
getCategoryActionNew_variable()
{
	return lang("Variable")
}

getParametersActionNew_variable()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Value")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a value"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: "StringOrExpression", contentParID: "expression", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionNew_variable(ID)
{
	global
	
	return % lang("New_variable") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}