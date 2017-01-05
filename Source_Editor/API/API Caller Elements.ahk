;This file provides functions which can be accessed while executing the elements.



x_replaceVariables(Environment, String, pars ="")
{
}
x_EvaluateExpression(Environment, String)
{
}
x_CheckVariableName(VarName)
{
}
x_GetVariable(Environment, Varname, p_hidden = False)
{
}
x_getVariableType(Environment, Varname, p_hidden = False)
{
}
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
}
x_DeleteVariable(Environment, Varname, p_hidden = False)
{
}

x_GetVariableLocation(Environment, Varname, p_hidden = False)
{
}


x_finish(Environment, Result, Message = "")
{
}
x_log(Environment, LoggingText, loglevel = 2)
{
}
x_NewUniqueExecutionID(Environment)
{
}
x_GetMyUniqueExecutionID(Environment)
{
}
x_DeleteMyUniqueExecutionID(Environment)
{
}
x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
}
x_SetExecutionValue(Environment, p_name, p_Value)
{
}
x_GetExecutionValue(Environment, p_name)
{
}
x_NewExecutionFunctionObject(Environment, p_ToCallFunction, params*)
{
	
}
x_GetListOfAllVars(Environment)
{
}
x_GetListOfLoopVars(Environment)
{
}
x_GetListOfThreadVars(Environment)
{
}
x_GetListOfInstanceVars(Environment)
{
}
x_GetListOfStaticVars(Environment)
{
}
x_GetListOfGlobalVars(Environment)
{
}
x_ExportAllInstanceVars(Environment)
{
}
x_ImportInstanceVars(Environment, p_VarsToImport)
{
}
x_GetMyElementID(Environment)
{
	global
	return setelementID
}
x_GetMyFlowID(Environment)
{
	global
	return flowobj.id
}
x_GetMyFlowName(Environment)
{
	global
	return flowobj.name
}
x_GetAllMyFlowTriggerNames(Environment)
{
	global flowObj
	elements:=Object()
	for oneID, oneElement in flowObj.allElements
	{
		if (oneElement.type = "trigger")
			elements.push(oneElement.name)
	}
	return elements
}
x_GetAllMyFlowManualTriggerNames(Environment)
{
	global flowObj
	elements:=Object()
	for oneID, oneElement in flowObj.allElements
	{
		if (oneElement.class = "trigger_manual")
			elements.push(oneElement.name)
	}
	return elements
}
x_GetAllManualTriggerNamesOfFlowByName(p_FlowName)
{
	global _flows
	elements:=Object()
	for oneFlowID, oneFlow in _flows
	{
		if (oneFlow.name = p_FlowName)
		{
			if (oneFlow.loaded!=True)
			{
				API_Main_LoadFlow(oneFlow.id)
			}
			for oneElementID, oneElement in oneFlow.allElements
			{
				if (oneElement.class = "trigger_manual")
					elements.push(oneElement.name)
			}
		}
		
	}
	return elements
}


x_GetAllMyFlowManualTriggers(Environment)
{
	global flowObj
	elements:=Object()
	for oneID, oneElement in flowObj.allElements
	{
		if (oneElement.class = "trigger_manual")
			elements.push(oneElement)
	}
	return elements
}

x_GetAllManualTriggersOfFlowByName(p_FlowName)
{
	global _flows
	elements:=Object()
	for oneFlowID, oneFlow in _flows
	{
		if (oneFlow.name = p_FlowName)
		{
			if (oneFlow.loaded!=True)
			{
				API_Main_LoadFlow(oneFlow.id)
			}
			for oneElementID, oneElement in oneFlow.allElements
			{
				if (oneElement.class = "trigger_manual")
					elements.push(oneElement)
			}
		}
		
	}
	return elements
}

x_getAllElementsOfClass(Environment, p_Class)
{
	global flowObj
	elements:=Object()
	for oneID, oneElement in flowObj.allElements
	{
		if (oneElement.class = p_Class)
			elements.push(objFullyClone(oneElement))
	}
	return elements
}

x_GetListOfFlowNames()
{
	global _flows
	;Search for all flowNames
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlow.name)
	}
	return choices
}


x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	
}
x_trigger(Environment, triggerVars="")
{
	
}
x_getEntryPoint(Environment)
{
	
}
x_enabled(Environment, Result, Message = "")
{
	
}
x_disabled(Environment, Result, Message = "")
{
	
}
x_Par_Disable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
	return ElementSettings.field.enable(p_ParameterID,not p_TrueOrFalse)
}
x_Par_Enable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
	return ElementSettings.field.enable(p_ParameterID,p_TrueOrFalse)
}
x_Par_SetValue(Environment,p_ParameterID, p_Value)
{
	return ElementSettings.field.setvalue(p_Value,p_ParameterID)
}
x_Par_GetValue(Environment,p_ParameterID)
{
	return ElementSettings.field.getvalue(p_ParameterID)
}
x_Par_SetChoices(Environment,p_ParameterID, p_Choices)
{
	return ElementSettings.field.setChoices(p_Choices,p_ParameterID)
}
x_FlowEnableByName(Environment, p_FlowName)
{
}
x_FlowDisableByName(Environment, p_FlowName)
{
}
x_FlowStopByName(Environment, p_FlowName)
{
}
x_FlowExecuteByName(Environment, p_FlowName, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
}
x_FlowExistsByName(Environment, p_FlowName)
{	
}
x_isFlowEnabledByName(Environment, p_FlowName)
{
}
x_isFlowExecutingByName(Environment, p_FlowName)
{
}
x_InstanceStop(Environment)
{
}
x_GetThreadCountInCurrentInstance(Environment)
{
}
x_randomPhrase()
{
	return randomPhrase()
}
x_ConvertObjToString(p_Value)
{
	if IsObject(p_Value)
		return strobj(p_Value)
}
x_ConvertStringToObj(p_Value)
{
	if not IsObject(p_Value)
		return strobj(p_Value)
}
x_ConvertStringToObjOrObjToString(p_Value)
{
	return strobj(p_Value)
}

x_GetFullPath(Environment, p_Path)
{
}

x_ExecuteInNewAHKThread_finishedExecution(Environment)
{
}



x_isTriggerEnabledByName(Environment, p_FlowName, p_TriggerName="")
{
}


x_TriggerEnableByName(Environment, p_FlowName, p_TriggerName="")
{
}


x_TriggerDisableByName(Environment, p_FlowName, p_TriggerName="")
{
}
