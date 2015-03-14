iniAllConditions.="Expression|" ;Add this condition to list of all conditions on initialisation

runConditionExpression(InstanceID,ElementID,ElementIDInInstance)
{
	
	global
	if (v_EvaluateExpression(InstanceID,%ElementID%Expression))
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"yes")
	else
		MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"no")
}



getParametersConditionExpression()
{
	
	parametersToEdit:=["Label|" lang("Expression"),"Text||Expression","Label| " lang("Value")]
	
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