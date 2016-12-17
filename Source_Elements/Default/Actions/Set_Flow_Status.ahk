;Always add this element class name to the global list
AllElementClasses.push("Action_Set_Flow_Status")

Element_getPackage_Action_Set_Flow_Status()
{
	return "default"
}

Element_getElementType_Action_Set_Flow_Status()
{
	return "action"
}

Element_getName_Action_Set_Flow_Status()
{
	return lang("Set_Flow_Status")
}

Element_getCategory_Action_Set_Flow_Status()
{
	return lang("Flow_control")
}

Element_getParameters_Action_Set_Flow_Status()
{
	return ["flowName", "Enable"]
}

Element_getParametrizationDetails_Action_Set_Flow_Status()
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Edit", id: "flowName", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("New state")})
	parametersToEdit.push({type: "Radio", id: "Enable", default: 1, choices: [lang("Enable"), lang("Disable")]})

	return parametersToEdit
}

Element_run_Action_Set_Flow_Status(Environment, ElementParameters)
{
	FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	
	if x_FlowExistsByName(Environment,FlowName)
	{
		if (ElementParameters.Enable = 1)
			x_FlowEnableByName(Environment,FlowName)
		else if (ElementParameters.Enable = 2)
			x_FlowDisableByName(Environment,FlowName)
		return x_finish(Environment,"normal")
		
	}
	else
	{
		return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
	}
	return
}

Element_GenerateName_Action_Set_Flow_Status(Environment, ElementParameters)
{
	if (ElementParameters.Enable)
		enableString:=lang("Enable")
	else
		enableString:=lang("Disable")
		return % lang("Set_Flow_Status") " - " enableString ": " ElementParameters.flowName
	
}