iniAllConditions.="Expression|" ;Add this condition to list of all conditions on initialisation

runConditionExpression(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	
	global
	if (v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Expression))
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"yes")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"no")
}



getParametersConditionExpression()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Expression")})
	parametersToEdit.push({type: "Edit", id: "Expression", content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

getNameConditionExpression()
{
	return lang("Expression")
}
getCategoryConditionExpression()
{
	return lang("Variable")
}

GenerateNameConditionExpression(ID)
{
	return lang("Expression") ": " GUISettingsOfElement%ID%Expression
	
}