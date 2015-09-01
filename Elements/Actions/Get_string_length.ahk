iniAllActions.="Get_string_length|" ;Add this action to list of all actions on initialisation

runActionGet_string_length(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempSearchText
	local OccurenceNumber
	local Offset
	local Result
	local Options
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	if %ElementID%expression=1
		temp:=v_replaceVariables(InstanceID,ThreadID,%ElementID%VarValue)
	else
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
	
	StringLen,Result,temp
	v_SetVariable(InstanceID,ThreadID,Varname,Result)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	
	
	return
}
getNameActionGet_string_length()
{
	return lang("Get_string_length")
}
getCategoryActionGet_string_length()
{
	return lang("Variable")
}

getParametersActionGet_string_length()
{
	global
		parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewLength", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", default: "section", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionGet_string_length(ID)
{
	global
	
	return % lang("Get_string_length") "`n" GUISettingsOfElement%ID%Varname " = " GUISettingsOfElement%ID%VarValue
	
}

CheckSettingsActionGet_string_length(ID)
{
	static previousLeftSide=0
	static previousRightSide=0
	
	
}