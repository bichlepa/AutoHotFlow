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
	return [ "Enable", "ThisFlow", "flowName", "WhichTrigger", "triggerName"]
}

Element_getParametrizationDetails_Action_Set_Flow_Status()
{
	choicesFlows := x_GetListOfFlowNames()
	allTriggers := x_GetAllMyFlowManualTriggers(Environment)
	choicesTriggers:=Object()
	for oneID, oneTrigger in allTriggers
	{
		choicesTriggers.push(oneTrigger.pars.id)
	}
	myFlowName:= x_GetMyFlowName(Environment)
	
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

Element_run_Action_Set_Flow_Status(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow)
		FlowName:=x_GetMyFlowName(Environment)
	else
	{
		FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
		
		if not x_FlowExistsByName(Environment,FlowName)
		{
			return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
		}
	}
	
	
	if (ElementParameters.WhichTrigger = 1)
	{
		
		if (ElementParameters.Enable = 1)
			x_FlowEnableByName(Environment,FlowName)
		else if (ElementParameters.Enable = 2)
			x_FlowDisableByName(Environment,FlowName)
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
		
		
		if (ElementParameters.Enable = 1)
			x_TriggerEnableByName(Environment,FlowName,TriggerName)
		else if (ElementParameters.Enable = 2)
			x_TriggerDisableByName(Environment,FlowName,TriggerName)
		return x_finish(Environment,"normal")
		
	}
	
	
	
	
	return
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
		x_Par_Disable(Environment,"triggerName")
		x_Par_SetValue(Environment,"triggerName", "")
	}
	else
	{
		x_Par_Enable(Environment,"triggerName")
	}	
	
	x_Par_Disable(Environment,"flowName",ElementParameters.ThisFlow)
	
	if (oldParFlowName!=ElementParameters.flowName or oldParThisFlow!=ElementParameters.ThisFlow)
	{
		oldParThisFlow:=ElementParameters.ThisFlow
		oldParFlowName:=ElementParameters.flowName
		
		if (ElementParameters.ThisFlow)
		{
			allTriggers := x_GetAllMyFlowManualTriggers(Environment)
		}
		else
		{
			allTriggers := x_GetAllManualTriggersOfFlowByName(ElementParameters.flowName)
		}
		choicesTriggers:=Object()
		for oneID, oneTrigger in allTriggers
		{
			choicesTriggers.push(oneTrigger.pars.id)
		}
		x_Par_SetChoices(Environment,"triggerName", choicesTriggers)
		
		toChoose:=choicesTriggers[1]
		for oneIndex, oneChoice in choicesTriggers
		{
			if (oneChoice = ElementParameters.triggerName)
			{
				toChoose:=oneChoice
			}
		}
		;~ d(choicesTriggers, tochoose)
		x_Par_SetValue(Environment,"triggerName", toChoose)
		
	}
	
}