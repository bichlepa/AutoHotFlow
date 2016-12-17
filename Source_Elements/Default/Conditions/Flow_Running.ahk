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

Element_getParametrizationDetails_Condition_Flow_Running()
{
	choices := x_GetListOfFlowNames()
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "name", choices: choices})

	return parametersToEdit
}

Element_run_Condition_Flow_Running(Environment, ElementParameters)
{
	restult:=false
	FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	
	if x_FlowExistsByName(Environment,FlowName)
	{
		restult:=x_isFlowExecutingByName(Environment,FlowName)
		if (restult)
			return x_finish(Environment,"yes")
		else
			return x_finish(Environment,"no")
	}
	else
	{
		return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
	}
	
}

Element_GenerateName_Condition_Flow_Running(Environment, ElementParameters)
{
	global
	return % lang("Flow_Executing") " - " ElementParameters.flowName
	
}