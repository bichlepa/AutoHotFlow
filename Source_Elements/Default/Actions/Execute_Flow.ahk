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
	return ["flowName", "SendLocalVars", "SkipDisabled", "WaitToFinish", "ReturnVariables"]
}

Element_getParametrizationDetails_Action_Execute_Flow()
{
	choices := x_GetListOfFlowNames()
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Flow_name")})
	parametersToEdit.push({type: "ComboBox", id: "flowName", content: "String", WarnIfEmpty: true, result: "name", choices: choices})
	parametersToEdit.push({type: "Label", label:  lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "SendLocalVars", default: 1, label: lang("Send local variables")})
	parametersToEdit.push({type: "Checkbox", id: "SkipDisabled", default: 0, label: lang("Skip disabled flows without error")})
	parametersToEdit.push({type: "Checkbox", id: "WaitToFinish", default: 0, label: lang("Wait for called flow to finish")})
	parametersToEdit.push({type: "Checkbox", id: "ReturnVariables", default: 0, label: lang("Return local variables to the calling flow")})

	return parametersToEdit
}

Element_run_Action_Execute_Flow(Environment, ElementParameters)
{
	FlowName := x_replaceVariables(Environment, ElementParameters.flowName)
	Variables:=Object()
	
	if x_FlowExistsByName(Environment,FlowName)
	{
		if x_isFlowEnabledByName(Environment,FlowName)
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
				x_FlowExecuteByName(Environment,FlowName, Variables, functionObject)
				
				return
			}
			else
			{
				x_FlowExecuteByName(Environment,FlowName, Variables)
				return x_finish(Environment,"normal")
			}
		}
		else
		{
			if (ElementParameters.SkipDisabled)
			{
				return x_finish(Environment,"normal",lang("Flow '%1%' is disabled",FlowName))
			}
			else
			{
				return x_finish(Environment,"exception",lang("Flow '%1%' is disabled",FlowName))
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
	return % lang("Execute_Flow") ": " ElementParameters.flowName
	
}

Element_CheckSettings_Action_Execute_Flow(Environment, ElementParameters)
{
	if (ElementParameters.WaitToFinish = False)
	{
		x_Par_Disable(Environment,"ReturnVariables")
		x_Par_SetValue(Environment,"ReturnVariables", False)
	}
	else
	{
		x_Par_Enable(Environment,"ReturnVariables")
	}
	
	
}