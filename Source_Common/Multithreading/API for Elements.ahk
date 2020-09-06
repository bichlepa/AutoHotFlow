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
	_getFlowIdByName(p_FlowName)
	return retval
}




x_FlowExists(p_FlowID)
{
	
	if (_existsFlow(p_FlowID))
		return true
	else 
		return false
}


x_isFlowEnabled(p_FlowID)
{
	if _getFlowProperty(p_FlowID, "enabled")
		return true
	else
		return False
}



x_isFlowExecuting(p_FlowID)
{
	if (_getFlowProperty(p_FlowID, "executing"))
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
	allFlowIDs := _getAllFlowIds()
	allFlowNames := []
	for oneIndex, oneFlowID in allFlowIDs
	{
		allFlowNames.push(_getFlowProperty(oneFlowID, "name"))
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return allFlowNames
}

x_GetListOfFlowIDs()
{
	return _getAllFlowIds()
}


x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	
	allElementIDs := _getAllElementIds(p_FlowID)

	elements:=Object()
	for oneElementIndex, oneElementID in allElementIDs
	{
		if (_getElementProperty(p_FlowID, oneElementID, "type") = p_Type)
			elements.push(oneElementID)
	}
	
	return elements
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	EnterCriticalSection(_cs_shared)
	
	allElementIDs := _getAllElementIds(p_FlowID)

	elements:=Object()
	for oneElementIndex, oneElementID in allElementIDs
	{
		if (_getElementProperty(p_FlowID, oneElementID, "class") = p_Class)
			elements.push(oneElementID)
	}
	
	LeaveCriticalSection(_cs_shared)
	
	return elements
}

x_getElementPars(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "pars")
}
x_getElementName(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "name")
}
x_getElementClass(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "class")
}

x_getMyElementPars(Environment)
{
	return _getElementProperty(Environment.flowID, Environment.elementID, "pars")
}

;Manual trigger
x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	EnterCriticalSection(_cs_shared)
	
	allElementIDs := _getAllElementIds(p_FlowID)
	result := false
	for forelementIndex, forelementID in allElementIDs
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_manual" and _getElementProperty(p_FlowID, forelementID, "defaultTrigger") = True)
			{
				;~ d(forElement)
				result :=true
				break
			}
		}
		else
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_Manual" and _getElementProperty(p_FlowID, forelementID, "pars.id") = p_TriggerName)
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
	
	allElementIDs := _getAllElementIds(p_FlowID)
	result:=false
	for forelementIndex, forelementID in allElementIDs
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_manual" and _getElementProperty(p_FlowID, forelementID, "defaultTrigger") = True)
			{
				;~ d(forElement)
				result:=_getElementProperty(p_FlowID, forelementID, "enabled")
				break
			}
		}
		else
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_Manual" and _getElementProperty(p_FlowID, forelementID, "pars.id") = p_TriggerName)
			{
				;~ d(forElement)
				result:=_getElementProperty(p_FlowID, forelementID, "enabled")
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

	allElementIDs := _getAllElementIds(p_FlowID)
	for forelementIndex, forelementID in allElementIDs
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_manual" and _getElementProperty(p_FlowID, forelementID, "defaultTrigger") = True)
			{
				;~ d(forElement)
				enableOneTrigger(p_FlowID, forelementID)
			}
		}
		else
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_Manual" and _getElementProperty(p_FlowID, forelementID, "pars.id") = p_TriggerName)
			{
				;~ d(forElement)
				enableOneTrigger(p_FlowID, forelementID)
			}
		}
	}
	LeaveCriticalSection(_cs_shared)

}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs_shared)
	
	allElementIDs := _getAllElementIds(p_FlowID)
	for forelementIndex, forelementID in allElementIDs
	{
		;~ d(forelement, p_TriggerName)
		if (p_TriggerName = "")
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_manual" and _getElementProperty(p_FlowID, forelementID, "defaultTrigger") = True)
			{
				;~ d(forElement)
				disableOneTrigger(p_FlowID, forelementID)
			}
		}
		else
		{
			if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_Manual" and _getElementProperty(p_FlowID, forelementID, "pars.id") = p_TriggerName)
			{
				;~ d(forElement)
				disableOneTrigger(p_FlowID, forelementID)
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
	
	if _existsFlow(p_FlowID)
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
			allElementIDs := _getAllElementIds(p_FlowID)
			foundElementID:=""
			for forelementIndex, forelementID in allElementIDs
			{
				;~ d(forelement, p_TriggerName)
				if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_Manual" and _getElementProperty(p_FlowID, forelementID, "pars.id") = p_TriggerName)
				{
					foundElementID:=forelementID
					break
				}
			}
			LeaveCriticalSection(_cs_shared)

			if foundElementID
			{
				executeFlow(p_FlowID, foundElementID, params)
			}
			else
			{
				logger("f0", "Cannot trigger a manual trigger in flow '" _getFlowProperty(p_FlowID, "name") "'. Trigger '" p_TriggerName "' not found")
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
		return Environment.FirstCallOfCheckSettings ; TODO
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
	logger("f" loglevel, "Element " _getElementProperty(Environment.FlowID, Environment.elementID, "name") " (" Environment.elementID "): " LoggingText, _getFlowProperty(Environment.FlowID, "name"))
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
	if (_getFlowProperty(Environment.FlowID, "flowsettings.DefaultWorkingDir"))
	{
		return _getSettings("FlowWorkingDir")
	}
	else
	{
		return _getFlowProperty(Environment.FlowID, "flowsettings.workingdir")
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
	return _getShared("WindowsStartup")
}
