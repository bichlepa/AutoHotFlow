;Always add this element class name to the global list
x_RegisterElementClass("Condition_Flow_Enabled")

;Element type of the element
Element_getElementType_Condition_Flow_Enabled()
{
	return "condition"
}

;Name of the element
Element_getName_Condition_Flow_Enabled()
{
	return x_lang("Flow_Enabled")
}

;Category of the element
Element_getCategory_Condition_Flow_Enabled()
{
	return x_lang("Flow_control")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Flow_Enabled()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Flow_Enabled()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_Flow_Enabled()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Flow_Enabled()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Flow_Enabled(Environment)
{
	choicesFlows := x_GetListOfFlowNames()
	
	FlowID := x_GetMyFlowID(Environment)
	myFlowName := x_GetMyFlowName(Environment)
	
	allTriggerIDs := x_getAllElementIDsOfClass(FlowID, "manual_trigger")
	
	choicesTriggers:=Object()
	for oneIDIndex, oneTriggerID in allTriggerIDs
	{
		elementPars:=x_getElementPars(FlowID, oneTriggerID)
		choicesTriggers.push(elementPars.id)
	}
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Flow_name")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: x_lang("This flow (%1%)",myFlowName ) })
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesFlows})
	parametersToEdit.push({type: "Label", label: x_lang("Which Trigger")})
	parametersToEdit.push({type: "Radio", id: "WhichTrigger", default: 1, result: "enum", choices: [x_lang("Any trigger"), x_lang("Default trigger"), x_lang("Specific trigger")], enum: ["Any", "Default", "Specific"]})
	parametersToEdit.push({type: "ComboBox", id: "triggerName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesTriggers})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Flow_Enabled(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow = True)
		FlowName:=x_lang("This flow")
	else
		FlowName:=ElementParameters.flowName
	if (ElementParameters.WhichTrigger = "Any")
		TriggerName:=x_lang("Any trigger")
	else if (ElementParameters.WhichTrigger = "Default")
		TriggerName:=x_lang("Default trigger")
	else
		TriggerName:=ElementParameters.TriggerName
	return % x_lang("Flow_enabled") ": " FlowName " - " TriggerName
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Flow_Enabled(Environment, ElementParameters)
{
	static oldParFlowName
	static oldParThisFlow
	
	if (ElementParameters.WhichTrigger != "Default trigger")
	{
		x_Par_Disable("triggerName")
		x_Par_SetValue("triggerName", "")
	}
	else
	{
		x_Par_Enable("triggerName")
	}	
	
	x_Par_Disable("flowName",ElementParameters.ThisFlow)
	
	if (oldParFlowName!=ElementParameters.flowName or oldParThisFlow!=ElementParameters.ThisFlow)
	{
		oldParThisFlow:=ElementParameters.ThisFlow
		oldParFlowName:=ElementParameters.flowName
		
		
		
		if (ElementParameters.ThisFlow)
		{
			FlowID := x_getMyFlowID(Environment)
		}
		else
		{
			FlowID := x_getFlowIDByName(ElementParameters.flowName)
		}
		allTriggerIDs := x_getAllElementIDsOfClass(FlowID, "manual_trigger")
		
		choicesTriggers:=Object()
		for oneIndex, oneTriggerID in allTriggerIDs
		{
			elementPars:=x_getElementPars(FlowID, oneTriggerID)
			choicesTriggers.push(elementPars.id)
		}
		x_Par_SetChoices("triggerName", choicesTriggers)
		
		toChoose:=choicesTriggers[1]
		for oneIndex, oneChoice in choicesTriggers
		{
			if (oneChoice = ElementParameters.triggerName)
			{
				toChoose:=oneChoice
			}
		}
		;~ d(choicesTriggers, tochoose)
		x_Par_SetValue("triggerName", toChoose)
		
	}
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Flow_Enabled(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow)
		FlowName:=x_GetMyFlowName(Environment)
	else
	{
		FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
		
		if not x_FlowExistsByName(FlowName)
		{
			return x_finish(Environment,"exception",x_lang("Flow '%1%' does not exist",FlowName))
		}
	}
	FlowID:=x_getFlowIDByName(FlowName)
	
	if (ElementParameters.WhichTrigger = "Any")
	{
		if x_isFlowEnabled(FlowID)
		{
			return x_finish(Environment,"yes")
		}
		else
		{
			return x_finish(Environment,"no")
		}
	}
	else 
	{
		if (ElementParameters.WhichTrigger = "Default")
		{
			TriggerName := ""
		}
		else
		{
			TriggerName := x_replaceVariables(Environment, ElementParameters.triggerName)
			if (TriggerName ="")
			{
				return x_finish(Environment,"exception",x_lang("Trigger name is empty",FlowName))
			}
		}
		
		if (x_isManualTriggerEnabled(FlowID, TriggerName))
		{
			return x_finish(Environment,"yes")
		}
		else
		{
			return x_finish(Environment,"no")
		}
		
	}
	
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Flow_Enabled(Environment, ElementParameters)
{

}