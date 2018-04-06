;Always add this element class name to the global list
x_RegisterElementClass("Condition_Flow_Enabled")

Element_getPackage_Condition_Flow_Enabled()
{
	return "default"
}

Element_getElementType_Condition_Flow_Enabled()
{
	return "condition"
}

Element_getElementLevel_Condition_Flow_Enabled()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
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
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "ThisFlow"})
	parametersToEdit.push({id: "flowName"})
	parametersToEdit.push({id: "WhichTrigger"})
	parametersToEdit.push({id: "triggerName"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Condition_Flow_Enabled(Environment)
{
	global _flows
	
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
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: lang("This flow (%1%)",myFlowName ) })
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesFlows})
	parametersToEdit.push({type: "Label", label: lang("Which Trigger")})
	parametersToEdit.push({type: "Radio", id: "WhichTrigger", default: 1, result: "enum", choices: [lang("Any trigger"), lang("Default trigger"), lang("Specific trigger")], enum: ["Any", "Default", "Specific"]})
	parametersToEdit.push({type: "ComboBox", id: "triggerName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesTriggers})

	return parametersToEdit
}

Element_GenerateName_Condition_Flow_Enabled(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow = True)
		FlowName:=lang("This flow")
	else
		FlowName:=ElementParameters.flowName
	if (ElementParameters.WhichTrigger = "Any")
		TriggerName:=lang("Any trigger")
	else if (ElementParameters.WhichTrigger = "Default")
		TriggerName:=lang("Default trigger")
	else
		TriggerName:=ElementParameters.TriggerName
	return % lang("Flow_enabled") ": " FlowName " - " TriggerName
	
}

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

Element_run_Condition_Flow_Enabled(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow)
		FlowName:=x_GetMyFlowName(Environment)
	else
	{
		FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
		
		if not x_FlowExistsByName(FlowName)
		{
			return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
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
				return x_finish(Environment,"exception",lang("Trigger name is empty",FlowName))
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
