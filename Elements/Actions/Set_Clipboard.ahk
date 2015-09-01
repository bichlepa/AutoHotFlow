iniAllActions.="Set_Clipboard|" ;Add this action to list of all actions on initialisation

runActionSet_Clipboard(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempText
	
	if %ElementID%expression=1
		tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text)
	else
		tempText:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%text)
	
	Clipboard:=tempText
	

	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
GetNameActionSet_Clipboard()
{
	return lang("Set Clipboard")
}
GetCategoryActionSet_Clipboard()
{
	return lang("Variable")
}

GetParametersActionSet_Clipboard()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Text to set")})
	parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a string"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "text", default: "New element", content: "StringOrExpression", contentParID: "expression", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionSet_Clipboard(ID)
{
	global
	
	return % lang("Set_Clipboard") " - " GUISettingsOfElement%ID%text
	
}