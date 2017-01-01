;Always add this element class name to the global list
AllElementClasses.push("Action_Execute_Flow")

Element_getPackage_Action_Execute_Flow()
{
	return "default"
}

Element_getElementType_Action_Execute_Flow()
{
	return "action"
}

Element_getName_Action_Execute_Flow()
{
	return lang("Execute_Flow")
}

Element_getCategory_Action_Execute_Flow()
{
	return lang("Flow_control")
}

Element_getParameters_Action_Execute_Flow()
{
	return ["ThisFlow", "flowName", "DefaultTrigger", "triggerName", "SendLocalVars", "SkipDisabled", "WaitToFinish", "ReturnVariables"]
}

Element_getParametrizationDetails_Action_Execute_Flow()
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
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "Checkbox", id: "ThisFlow", default: 1, label: lang("This flow (%1%)",myFlowName ) })
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesFlows})
	parametersToEdit.push({type: "Label", label: lang("Trigger")})
	parametersToEdit.push({type: "Checkbox", id: "DefaultTrigger", default: 1, label: lang("Default trigger") })
	parametersToEdit.push({type: "ComboBox", id: "triggerName", content: "String", WarnIfEmpty: true, result: "string", choices: choicesTriggers})
	parametersToEdit.push({type: "Label", label:  lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "SendLocalVars", default: 1, label: lang("Send local variables")})
	parametersToEdit.push({type: "Checkbox", id: "SkipDisabled", default: 0, label: lang("Skip disabled flows without error")})
	parametersToEdit.push({type: "Checkbox", id: "WaitToFinish", default: 0, label: lang("Wait for called flow to finish")})
	parametersToEdit.push({type: "Checkbox", id: "ReturnVariables", default: 0, label: lang("Return local variables to the calling flow")})

	return parametersToEdit
}

Element_run_Action_Execute_Flow(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow)
		FlowName:=x_GetMyFlowName(Environment)
	else
		FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	Variables:=Object()
	
	if (ElementParameters.DefaultTrigger)
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
	if (TriggerName = "")
		TriggerNameText:=lang("Default trigger")
	else
		TriggerNameText:=TriggerName
	if (FlowName = "")
		FlowNameText:=lang("This flow")
	else
		FlowNameText:=FlowName
	
	if x_FlowExistsByName(Environment,FlowName)
	{
		if x_isTriggerEnabledByName(Environment,FlowName, TriggerName)
		{
			if (ElementParameters.SendLocalVars = True)
			{
				Variables:=x_ExportAllInstanceVars(Environment)
			}
			if (ElementParameters.WaitToFinish)
			{
				uniqueID:=x_NewUniqueExecutionID(Environment)
				
				functionObject:= x_NewExecutionFunctionObject(environment, uniqueID, "Action_Execute_Flow_FunctionExecutionFinished", ElementParameters)
				x_SetExecutionValue(uniqueID, "hotkey", temphotkey)
				x_FlowExecuteByName(Environment,FlowName, TriggerName, Variables, functionObject)
				
				return
			}
			else
			{
				x_FlowExecuteByName(Environment,FlowName, TriggerName, Variables)
				return x_finish(Environment,"normal")
			}
		}
		else
		{
			if (ElementParameters.SkipDisabled)
			{
				return x_finish(Environment,"normal",lang("Trigger '%1%' in '%2%' is disabled",TriggerNameText, FlowNameText))
			}
			else
			{
				return x_finish(Environment,"exception",lang("Trigger '%1%' in '%2%' is disabled",TriggerNameText, FlowNameText))
			}
		}
	}
	else
	{
		return x_finish(Environment,"exception",lang("Flow '%1%' does not exist",FlowName))
	}
	return
}

Action_Execute_Flow_FunctionExecutionFinished(Environment, p_result, p_variables, ElementParameters)
{
	uniqueID:=x_GetMyUniqueExecutionID(Environment)
	functionObject:=x_getExecutionValue(uniqueID, "functionObject")
	x_DeleteMyUniqueExecutionID(Environment)
	if (ElementParameters.ReturnVariables)
		x_ImportInstanceVars(Environment, p_variables)
	return x_finish(Environment,"normal")
}

Element_GenerateName_Action_Execute_Flow(Environment, ElementParameters)
{
	if (ElementParameters.ThisFlow = True)
		FlowName:=lang("This flow")
	else
		FlowName:=ElementParameters.flowName
	if (ElementParameters.defaultTrigger = True)
		TriggerName:=lang("Default trigger")
	else
		TriggerName:=ElementParameters.TriggerName
	return % lang("Execute_Flow") ": " FlowName " - " TriggerName
	
}

Element_CheckSettings_Action_Execute_Flow(Environment, ElementParameters)
{
	static oldParFlowName
	static oldParThisFlow
	if (ElementParameters.WaitToFinish = False)
	{
		x_Par_Disable(Environment,"ReturnVariables")
		x_Par_SetValue(Environment,"ReturnVariables", False)
	}
	else
	{
		x_Par_Enable(Environment,"ReturnVariables")
	}	
	
	if (ElementParameters.defaultTrigger = True)
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