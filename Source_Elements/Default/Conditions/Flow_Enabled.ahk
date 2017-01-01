;Always add this element class name to the global list
AllElementClasses.push("Condition_Flow_Enabled")

Element_getPackage_Condition_Flow_Enabled()
{
	return "default"
}

Element_getElementType_Condition_Flow_Enabled()
{
	return "condition"
}

Element_getName_Condition_Flow_Enabled()
{
	return lang("Flow_Enabled")
}

Element_getCategory_Condition_Flow_Enabled()
{
	return lang("Flow_control")
}

Element_getParameters_Condition_Flow_Enabled()
{
	return ["flowName"]
}

Element_getParametrizationDetails_Condition_Flow_Enabled()
{
	global _flows
	parametersToEdit:=Object()
	
	;Search for all flowNames
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlow.name)
	}
	
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "string", choices: choices})

	return parametersToEdit
}

Element_run_Condition_Flow_Enabled(Environment, ElementParameters)
{
	restult:=false
	FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	
	if x_FlowExistsByName(Environment,FlowName)
	{
		restult:=x_isFlowEnabledByName(Environment,FlowName)
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

Element_GenerateName_Condition_Flow_Enabled(Environment, ElementParameters)
{
	global
	return % lang("Flow_Enabled") " - " ElementParameters.flowName
	
}