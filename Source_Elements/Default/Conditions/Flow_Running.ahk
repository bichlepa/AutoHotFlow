;Always add this element class name to the global list
AllElementClasses.push("Condition_Flow_Running")

Element_getPackage_Condition_Flow_Running()
{
	return "default"
}

Element_getElementType_Condition_Flow_Running()
{
	return "condition"
}

Element_getName_Condition_Flow_Running()
{
	return lang("Flow_Executing")
}

Element_getCategory_Condition_Flow_Running()
{
	return lang("Flow_control")
}

Element_getParameters_Condition_Flow_Running()
{
	return ["flowName"]
}

Element_getParametrizationDetails_Condition_Flow_Running(Environment)
{
	choices := x_GetListOfFlowNames()
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "string", choices: choices})

	return parametersToEdit
}

Element_GenerateName_Condition_Flow_Running(Environment, ElementParameters)
{
	global
	return % lang("Flow_Executing") " - " ElementParameters.flowName
	
}

Element_run_Condition_Flow_Running(Environment, ElementParameters)
{
	result:=false
	FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	
	if x_FlowExistsByName(FlowName)
	{
		FlowID:=x_getFlowIDByName(FlowName)
		
		result:=x_isFlowExecuting(FlowID)
		if (result)
			return x_finish(Environment,"yes")
		else
			return x_finish(Environment,"no")
	}
	else
	{
		return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
	}
	
}