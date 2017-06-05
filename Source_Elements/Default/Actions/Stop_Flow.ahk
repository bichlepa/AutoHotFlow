;Always add this element class name to the global list
AllElementClasses.push("Action_Stop_Flow")

Element_getPackage_Action_Stop_Flow()
{
	return "default"
}

Element_getElementType_Action_Stop_Flow()
{
	return "action"
}

Element_getElementLevel_Action_Stop_Flow()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Stop_Flow()
{
	return lang("Stop_Flow")
}

Element_getCategory_Action_Stop_Flow()
{
	return lang("Flow_control")
}

Element_getParameters_Action_Stop_Flow()
{
	return ["flowName"]
}

Element_getParametrizationDetails_Action_Stop_Flow(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Edit", id: "flowName", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

Element_GenerateName_Action_Stop_Flow(Environment, ElementParameters)
{
	return % lang("Stop_Flow") ": " ElementParameters.flowName
	
}

Element_run_Action_Stop_Flow(Environment, ElementParameters)
{
	FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	
	if x_FlowExistsByName(FlowName)
	{
		FlowID:=x_getFlowIDByName(FlowName)
		x_FlowStop(FlowID)
		return x_finish(Environment,"normal")
		
	}
	else
	{
		return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
	}
	return
}