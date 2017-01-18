;This file provides functions which can be accessed while executing the elements.
;Editor thread


;Variable API functions:
x_GetVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Get_Common(Environment, Varname, p_hidden )
}
x_getVariableType(Environment, p_Varname, p_hidden = False)
{
	return Var_GetType_Common(Environment, Varname, p_hidden )
}
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	global
	return Var_Set_Common(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
x_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	global
	return Var_Delete_Common(Environment, Varname, p_hidden)
}

x_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	global
	return Var_GetLocation_Common(Environment, Varname, p_hidden)
}

x_replaceVariables(Environment, p_String, p_pars ="")
{
	global
	return Var_replaceVariables_Common(Environment, String, pars)
}
x_EvaluateExpression(Environment, p_String)
{
	global
	return Var_EvaluateExpression(Environment, String, "Var_Get_Common")
}
x_CheckVariableName(p_VarName)
{
	return Var_CheckName(VarName)
}


x_GetListOfAllVars(Environment)
{
	return Var_GetListOfAllVars_Common(Environment)
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
	return Var_GetListOfStaticVars(Environment)
}
x_GetListOfGlobalVars(Environment)
{
	return Var_GetListOfGlobalVars(Environment)
}
x_ExportAllInstanceVars(Environment)
{
}
x_ImportInstanceVars(Environment, p_VarsToImport)
{
}

;Execution (not supported here)

x_finish(Environment, p_Result, p_Message = "")
{
}
x_getEntryPoint(Environment) ;For loops
{
}
x_InstanceStop(Environment)
{
}
x_GetMyUniqueExecutionID(Environment)
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
x_GetThreadCountInCurrentInstance(Environment)
{
}
x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
}
;Trigger functions (not supported here)
x_trigger(Environment)
{
}
x_enabled(Environment, Result, Message = "")
{
}
x_disabled(Environment, Result, Message = "")
{
}


;get some information

x_GetMyFlowID(Environment)
{
	return Environment.FlowID
}
x_GetMyFlowName(Environment)
{
	global _flows
	return _flows[Environment.FlowID].name
}

x_GetMyElementID(Environment)
{
	return Environment.elementID
}

x_getFlowIDByName(p_FlowName)
{
	global _flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			return forFlowID
		}
	}
}




x_FlowExists(p_FlowID)
{
	global _Flows
	if (_Flows[p_FlowID].id)
		return true
	else 
		return false
}


x_isFlowEnabled(p_FlowID)
{
	global _Flows
	if _flows[p_FlowID].enabled
		return true
	else
		return False
}



x_isFlowExecuting(p_FlowID)
{
	global _Flows
	if (_Flows[p_FlowID].executing)
		return true
	else
		return False
}


x_FlowEnable(p_FlowID)
{
	global _Flows
	if x_FlowExists(p_FlowID)
		API_Main_enableFlow(p_FlowID)

}


x_FlowDisable(p_FlowID)
{
	global _Flows
	if x_FlowExists(p_FlowID)
		API_Main_disableFlow(p_FlowID)
	
}

x_FlowStop(p_FlowID)
{
	global _Flows
	
	if x_FlowExists(p_FlowID)
		API_Main_stopFlow(p_FlowID)
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

x_GetListOfFlowIDs()
{
	global _flows
	;Search for all flowNames
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlowID)
	}
	return choices
}


x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	global _flows
	
	elements:=Object()
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = p_Class)
			elements.push(oneElementID)
	}
	return elements
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	global _flows
	
	elements:=Object()
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = p_Class)
			elements.push(oneElementID)
	}
	return elements
}

x_getElementPars(p_FlowID, p_ElementID)
{
	global _flows
	return objfullyClone(_flows[p_FlowID].allElements[p_ElementID].pars)
}
x_getElementName(p_FlowID, p_ElementID)
{
	global _flows
	return _flows[p_FlowID].allElements[p_ElementID].name
}
x_getElementClass(p_FlowID, p_ElementID)
{
	global _flows
	return _flows[p_FlowID].allElements[p_ElementID].class
}


;Manual trigger
x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	global _Flows
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				return true
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				return true
			}
		}
		
	}
	return False
}

x_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	global _Flows
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				return forElement.enabled 
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				return forElement.enabled 
			}
		}
		
	}
	return False
}

x_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	global _Flows
	
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				API_Main_enableOneTrigger(forFlow.id, forelement.id)
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				API_Main_enableOneTrigger(forFlow.id, forelement.id)
			}
		}
	}

}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	global _Flows
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				API_Main_disableOneTrigger(forFlow.id, forelement.id)
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				API_Main_disableOneTrigger(forFlow.id, forelement.id)
			}
		}
	}

}

x_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
	global _Flows
	global _share
	random, randomnumber
	_share.temp[randomnumber]:=Object()
	_share.temp[randomnumber].CallBack:=p_CallBackFunction
	
	;Fill variables which will be passed
			;~ _share.temp[randomnumber].varstoPass:=p_Variables
	varsToPass:=p_Variables
	_share.temp[randomnumber].varsToPass:=varsToPass
	
	
	if x_FlowExists(p_FlowID)
	{
		
		;~ d(_share.temp)
		if (p_TriggerName = "")
		{
			;~ d(p_FlowName)
			API_Main_executeFlow(p_FlowID, "", randomnumber)
			return
		}
		else
		{
			;~ d(p_FlowName " - " p_TriggerName)
			for forelementID, forelement in _flows[p_FlowID].allElements
			{
				;~ d(forelement, p_TriggerName)
				if forelement.class = "trigger_Manual"
				{
					if (forelement.pars.id = p_TriggerName)
					{
						;~ d(forFlow.id,forelementID)
						API_Main_executeFlow(p_FlowID, forelementID, randomnumber)
						return
					}
				}
			}
		}
	}
}




;while editing

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


;common functions. Available everywhere
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



x_log(Environment, LoggingText, loglevel = 2)
{
	global _flows
	logger("f" loglevel, "Flow: " _flows[Environment.FlowID].name " (" Environment.FlowID ") - Element " _flows[Environment.FlowID].allElements[Environment.elementID].name " (" Environment.elementID "): " LoggingText)
}
x_GetFullPath(Environment, p_Path)
{
	global _Flows
	path:=p_Path
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",path)
		path:=_Flows[Environment.FlowID].flowsettings.workingdir "\" path
	return path
}




x_FlowExistsByName(p_FlowName)
{
}
