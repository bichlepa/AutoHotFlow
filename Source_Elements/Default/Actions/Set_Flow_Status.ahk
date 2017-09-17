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

Element_getElementLevel_Action_Set_Flow_Status()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
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
	return [ "Enable", "ThisFlow", "flowName", "WhichTrigger", "triggerName"]
}

Element_getParametrizationDetails_Action_Set_Flow_Status(Environment)
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
	parametersToEdit.push({type: "Label", label: lang("New state")})
	parametersToEdit.push({type: "Radio", id: "Enable", default: 1, choices: [lang("Enable"), lang("Disable")]})
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: lang("This flow (%1%)",myFlowName ) })
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesFlows})
	parametersToEdit.push({type: "Label", label: lang("Trigger")})
	parametersToEdit.push({type: "Radio", id: "WhichTrigger", default: 1, choices: [lang("Any trigger"), lang("Default trigger"), lang("Specific trigger")], label: lang("Which trigger") })
	parametersToEdit.push({type: "ComboBox", id: "triggerName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesTriggers})

	return parametersToEdit
}

Element_GenerateName_Action_Set_Flow_Status(Environment, ElementParameters)
{
	if (ElementParameters.Enable)
		enableString:=lang("Enable")
	else
		enableString:=lang("Disable")
	
	if (ElementParameters.ThisFlow = True)
		FlowName:=lang("This flow")
	else
		FlowName:=ElementParameters.flowName
	if (ElementParameters.WhichTrigger = 1)
		TriggerName:=lang("Any trigger")
	else if (ElementParameters.WhichTrigger = 2)
		TriggerName:=lang("Default trigger")
	else
		TriggerName:=ElementParameters.TriggerName
	return % lang("Set_Flow_Status") " - " enableString ": " FlowName " - " TriggerName
	
	
}


Element_CheckSettings_Action_Set_Flow_Status(Environment, ElementParameters)
{
	static oldParFlowName
	static oldParThisFlow
	
	if (ElementParameters.WhichTrigger != 3)
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

Element_run_Action_Set_Flow_Status(Environment, ElementParameters)
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
	
	
	if (ElementParameters.WhichTrigger = 1)
	{
		
		if (ElementParameters.Enable = 1)
			x_FlowEnable(FlowID)
		else if (ElementParameters.Enable = 2)
			x_FlowDisable(FlowID)
		return x_finish(Environment,"normal")
	
	}
	else 
	{
		if (ElementParameters.WhichTrigger = 2)
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
		
		if not x_ManualTriggerExist(FlowID, TriggerName)
		{
			return x_finish(Environment,"exception",lang("Trigger '%1%' in flow '%2%' does not exist",TriggerNameText, FlowName))
		}
		
		if (ElementParameters.Enable = 1)
			x_ManualTriggerEnable(FlowID,TriggerName)
		else if (ElementParameters.Enable = 2)
			x_ManualTriggerDisable(FlowID,TriggerName)
		return x_finish(Environment,"normal")
		
	}
	
	
	
	
	return
}