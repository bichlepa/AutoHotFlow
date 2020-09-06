;This file provides functions which can be accessed while executing the elements.


x_RegisterElementClass(p_class)
{
	if (_ahkThreadID = "main")
		Element_Register_Element_Class(p_class)
}

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
	return Var_Set_Common(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
x_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Delete_Common(Environment, Varname, p_hidden)
}

x_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	return Var_GetLocation_Common(Environment, Varname, p_hidden)
}

x_replaceVariables(Environment, p_String, p_pars ="")
{
	return Var_replaceVariables_Common(Environment, String, pars)
}
x_EvaluateExpression(Environment, p_String)
{
	return Var_EvaluateExpression(Environment, String, "Var_Get_Common", "Var_Set_Common")
}
x_CheckVariableName(p_VarName)
{
	return Var_CheckName(VarName)
}

x_AutoEvaluateParameters(Environment, ElementParameters, p_skipList = "")
{
	return
}
x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
	return
}
x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
	return
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
	return _getFlowProperty(Environment.FlowID, "name")
}

x_GetMyElementID(Environment)
{
	return Environment.elementID
}

x_getFlowIDByName(p_FlowName)
{
	EnterCriticalSection(_cs_shared)
	
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			retval:= forFlowID
		}
	}
	
	LeaveCriticalSection(_cs_shared)
	return retval
}




x_FlowExists(p_FlowID)
{
	if (_Flows[p_FlowID].id)
		return true
	else 
		return false
}


x_isFlowEnabled(p_FlowID)
{
	if _flows[p_FlowID].enabled
		return true
	else
		return False
}



x_isFlowExecuting(p_FlowID)
{
	if (_Flows[p_FlowID].executing)
		return true
	else
		return False
}


x_FlowEnable(p_FlowID)
{
	if x_FlowExists(p_FlowID)
		enableFlow(p_FlowID)

}


x_FlowDisable(p_FlowID)
{
	if x_FlowExists(p_FlowID)
		disableFlow(p_FlowID)
	
}

x_FlowStop(p_FlowID)
{
	if x_FlowExists(p_FlowID)
		stopFlow(p_FlowID)
}


x_GetListOfFlowNames()
{
	EnterCriticalSection(_cs_shared)
	
	;Search for all flowNames
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlow.name)
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return choices
}

x_GetListOfFlowIDs()
{
	EnterCriticalSection(_cs_shared)
	
	;Search for all flowNames
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlowID)
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return choices
}


x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	EnterCriticalSection(_cs_shared)
	
	elements:=Object()
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = p_Class)
			elements.push(oneElementID)
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return elements
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	EnterCriticalSection(_cs_shared)
	
	elements:=Object()
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = p_Class)
			elements.push(oneElementID)
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return elements
}

x_getElementPars(p_FlowID, p_ElementID)
{
	EnterCriticalSection(_cs_shared)
	retval:=objfullyClone(_flows[p_FlowID].allElements[p_ElementID].pars)
	LeaveCriticalSection(_cs_shared)
	return retval
}
x_getElementName(p_FlowID, p_ElementID)
{
	return _flows[p_FlowID].allElements[p_ElementID].name
}
x_getElementClass(p_FlowID, p_ElementID)
{
	return _flows[p_FlowID].allElements[p_ElementID].class
}

x_getMyElementPars(Environment)
{
	EnterCriticalSection(_cs_shared)
	retval:=objfullyClone(_flows[Environment.flowID].allElements[Environment.FlowID].pars)
	LeaveCriticalSection(_cs_shared)
	return retval
}

;Manual trigger
x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	EnterCriticalSection(_cs_shared)
	
	result:=false
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				result :=true
				break
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				result :=true
				break
			}
		}
		
	}
	LeaveCriticalSection(_cs_shared)
	return result
}

x_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs_shared)
	
	result:=false
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				result:=forElement.enabled
				break
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				result:=forElement.enabled
				break
			}
		}
		
	}
	
	LeaveCriticalSection(_cs_shared)
	return result
}

x_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs_shared)
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				enableOneTrigger(forFlow.id, forelement.id)
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				enableOneTrigger(forFlow.id, forelement.id)
			}
		}
	}
	LeaveCriticalSection(_cs_shared)

}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs_shared)
	for forelementID, forelement in _flows[p_FlowID].allElements
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (forElement.class = "trigger_manual" and forElement.defaultTrigger = True)
			{
				;~ d(forElement)
				disableOneTrigger(forFlow.id, forelement.id)
			}
		}
		else
		{
			if (forelement.class = "trigger_Manual" and forElement.pars.id = p_TriggerName)
			{
				;~ d(forElement)
				disableOneTrigger(forFlow.id, forelement.id)
			}
		}
	}

	LeaveCriticalSection(_cs_shared)
}

x_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
	params:=Object()
	params.VarsToPass:=p_Variables
	params.CallBack:=p_CallBackFunction
	
	if x_FlowExists(p_FlowID)
	{
		
		;~ d(_share.temp)
		if (p_TriggerName = "")
		{
			;~ d(p_FlowName)
			executeFlow(p_FlowID, "", params)
			return
		}
		else
		{
			;~ d(p_FlowName " - " p_TriggerName)
			EnterCriticalSection(_cs_shared)
			foundElementID:=""
			for forelementID, forelement in _flows[p_FlowID].allElements
			{
				;~ d(forelement, p_TriggerName)
				if forelement.class = "trigger_Manual"
				{
					if (forelement.pars.id = p_TriggerName)
					{
						foundElementID:=forelementID
						break
					}
				}
			}
			LeaveCriticalSection(_cs_shared)

			if foundElementID
			{
				executeFlow(p_FlowID, foundElementID, params)
			}
			else
			{
				;todo: log error
			}
		}
	}
}




;while editing

x_Par_Disable(p_ParameterID, p_TrueOrFalse = True)
{
	if (instr(_ahkThreadID,"Editor"))
		return ElementSettings.field.enable(p_ParameterID,not p_TrueOrFalse)
}
x_Par_Enable(p_ParameterID, p_TrueOrFalse = True)
{
	if (instr(_ahkThreadID,"Editor"))
		return ElementSettings.field.enable(p_ParameterID,p_TrueOrFalse)
}
x_Par_SetValue(p_ParameterID, p_Value)
{
	if (instr(_ahkThreadID,"Editor"))
		return ElementSettings.field.setvalue(p_Value,p_ParameterID)
}
x_Par_GetValue(p_ParameterID)
{
	if (instr(_ahkThreadID,"Editor"))
		return ElementSettings.field.getvalue(p_ParameterID)
}
x_Par_SetChoices(p_ParameterID, p_Choices)
{
	if (instr(_ahkThreadID,"Editor"))
		return ElementSettings.field.setChoices(p_Choices,p_ParameterID)
}
x_Par_SetLabel(p_ParameterID, p_Label)
{
	if (instr(_ahkThreadID,"Editor"))
		return ElementSettings.field.setLabel(p_Label,p_ParameterID)
}
x_FirstCallOfCheckSettings(Environment)
{
	if (instr(_ahkThreadID,"Editor"))
		return Environment.FirstCallOfCheckSettings
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
	logger("f" loglevel, "Element " _flows[Environment.FlowID].allElements[Environment.elementID].name " (" Environment.elementID "): " LoggingText, Environment.flowname)
}

x_GetFullPath(Environment, p_Path)
{
	path:=p_Path
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",path)
	{
		path := x_GetWorkingDir(Environment)
	}
	return path
}

x_GetWorkingDir(Environment)
{
	if (_Flows[Environment.FlowID].flowsettings.DefaultWorkingDir)
	{
		return _settings.FlowWorkingDir
	}
	else
	{
		return _Flows[Environment.FlowID].flowsettings.workingdir
	}
}



x_FlowExistsByName(p_FlowName)
{
}


x_EvaluateScript(Environment, p_script)
{
}


x_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
}


x_TriggerInNewAHKThread_GetExportedValues(Environment)
{
}


x_TriggerInNewAHKThread_Stop(Environment)
{
}


x_assistant_windowParameter(neededInfo)
{
	if (instr(_ahkThreadID,"Editor"))
	{
		assistant_GetWindowInformation%nothing%(neededInfo)
	}
}

x_assistant_MouseTracker(neededInfo)
{
	if (instr(_ahkThreadID,"Editor"))
	{
		assistant_MouseTracker%nothing%(neededInfo)
	}
}

x_assistant_ChooseColor(neededInfo)
{
	if (instr(_ahkThreadID,"Editor"))
	{
		assistant_ChooseColor%nothing%(neededInfo)
	}
}


x_GetAhfPath()
{
	return GetAhfPath()
}

x_isWindowsStartup()
{
	return _share.WindowStartup
}
