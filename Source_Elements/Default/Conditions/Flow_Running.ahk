;Always add this element class name to the global list
x_RegisterElementClass("Condition_Flow_Running")

;Element type of the element
Element_getElementType_Condition_Flow_Running()
{
	return "condition"
}

;Name of the element
Element_getName_Condition_Flow_Running()
{
	return x_lang("Flow_Executing")
}

;Category of the element
Element_getCategory_Condition_Flow_Running()
{
	return x_lang("Flow_control")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Flow_Running()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Flow_Running()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Condition_Flow_Running()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Flow_Running()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Flow_Running(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Which flow")})
	parametersToEdit.push({type: "DropDown", id: "flowID", result: "enum", choices: [], enum: []})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Flow_Running(Environment, ElementParameters)
{
	global
	return % x_lang("Flow_Executing") " - " x_getFlowName(ElementParameters.flowID)
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Flow_Running(Environment, ElementParameters, staticValues)
{	
	; we need to fill the flow list on first call
	if (x_FirstCallOfCheckSettings(Environment))
	{
		; get list of flows
		choicesFlowIDs := x_GetListOfFlowIDs()
		choicesFlowNames := []
		for oneFlowIndex, oneFlowID in choicesFlowIDs
		{
			choicesFlowNames.push(oneFlowID ": " x_getFlowName(oneFlowID))
		}
		
		; set choices
		x_Par_SetChoices("flowID", choicesFlowNames, choicesFlowIDs)

		; select flow
		flowID := ElementParameters.flowID
		if (not flowID)
		{
			; there is no flow ID specified. Set current flow ID
			flowID := x_GetMyFlowID(Environment)
		}
		x_Par_SetValue("flowID", flowID)
	}
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Flow_Running(Environment, ElementParameters)
{
	result := false
	FlowID := ElementParameters.FlowID
	
	if x_FlowExists(FlowID)
	{
		result := x_isFlowExecuting(FlowID)
		if (result)
			return x_finish(Environment, "yes")
		else
			return x_finish(Environment, "no")
	}
	else
	{
		return x_finish(Environment,"exception", x_lang("Flow '%1%' does not exist", FlowID))
	}
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Flow_Running(Environment, ElementParameters)
{

}