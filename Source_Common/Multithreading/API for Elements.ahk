;This file provides functions which can be accessed while executing the elements.

; only in main
xx_RegisterElementClass(p_class)
{
}

;Variable API functions:
xx_GetVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Get_Common(Environment, Varname, p_hidden )
}
xx_getVariableType(Environment, p_Varname, p_hidden = False)
{
	return Var_GetType_Common(Environment, Varname, p_hidden )
}
xx_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	return Var_Set_Common(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
xx_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Delete_Common(Environment, Varname, p_hidden)
}

xx_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	return Var_GetLocation_Common(Environment, Varname, p_hidden)
}

xx_replaceVariables(Environment, p_String, p_pars ="")
{
	return Var_replaceVariables_Common(Environment, String, pars)
}
xx_EvaluateExpression(Environment, p_String)
{
	return Var_EvaluateExpression(Environment, String, "Var_Get_Common", "Var_Set_Common")
}
xx_CheckVariableName(p_VarName)
{
	return Var_CheckName(VarName)
}

; only in execution
xx_AutoEvaluateParameters(Environment, ElementParameters, p_skipList = "")
{
}
xx_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
}
xx_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
}


xx_GetListOfAllVars(Environment)
{
	return Var_GetListOfAllVars_Common(Environment)
}


; only in execution
xx_GetListOfLoopVars(Environment)
{
}
xx_GetListOfThreadVars(Environment)
{
}
xx_GetListOfInstanceVars(Environment)
{
}


xx_GetListOfStaticVars(Environment)
{
	return Var_GetListOfStaticVars(Environment)
}
xx_GetListOfGlobalVars(Environment)
{
	return Var_GetListOfGlobalVars(Environment)
}


; only in execution
xx_ExportAllInstanceVars(Environment)
{
}
xx_ImportInstanceVars(Environment, p_VarsToImport)
{
}

; only in execution
xx_finish(Environment, p_Result, p_Message = "")
{
}
xx_getEntryPoint(Environment) ;For loops
{
}
xx_InstanceStop(Environment)
{
}
xx_GetMyUniqueExecutionID(Environment)
{
}
xx_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
}
xx_SetExecutionValue(Environment, p_name, p_Value)
{
}
xx_GetExecutionValue(Environment, p_name)
{
}
xx_NewExecutionFunctionObject(Environment, p_ToCallFunction, params*)
{
}
xx_GetThreadCountInCurrentInstance(Environment)
{
}
xx_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
}
; only in execution
xx_trigger(Environment)
{
}
xx_enabled(Environment, Result, Message = "")
{
}
xx_disabled(Environment, Result, Message = "")
{
}


;get some information
xx_GetMyFlowID(Environment)
{
	return Environment.FlowID
}
xx_GetMyFlowName(Environment)
{
	return _getFlowProperty(Environment.FlowID, "name")
}

xx_GetMyElementID(Environment)
{
	return Environment.elementID
}

xx_getFlowIDByName(p_FlowName)
{
	return _getFlowIdByName(p_FlowName)
}

xx_FlowExistsByName(p_FlowName)
{
	_EnterCriticalSection()
	
	;Search for all flowNames
	allFlowIDs := _getAllFlowIds()
	allFlowNames := []
	retval:=false
	for oneIndex, oneFlowID in allFlowIDs
	{
		if (_getFlowProperty(oneFlowID, "name") == p_FlowName)
		{
			retval:= True
			break
		}
	}
	
	_LeaveCriticalSection()
	return retval
}

xx_FlowExists(p_FlowID)
{
	return _existsFlow(p_FlowID)
}

xx_isFlowEnabled(p_FlowID)
{
	if _getFlowProperty(p_FlowID, "enabled")
		return true
	else
		return False
}

xx_isFlowExecuting(p_FlowID)
{
	if (_getFlowProperty(p_FlowID, "executing"))
		return true
	else
		return False
}

xx_FlowEnable(p_FlowID)
{
	if xx_FlowExists(p_FlowID)
		enableFlow(p_FlowID)

}

xx_FlowDisable(p_FlowID)
{
	if xx_FlowExists(p_FlowID)
		disableFlow(p_FlowID)
	
}

xx_FlowStop(p_FlowID)
{
	if xx_FlowExists(p_FlowID)
		stopFlow(p_FlowID)
}


xx_GetListOfFlowNames()
{
	_EnterCriticalSection()
	
	;Search for all flowNames
	allFlowIDs := _getAllFlowIds()
	allFlowNames := []
	for oneIndex, oneFlowID in allFlowIDs
	{
		allFlowNames.push(_getFlowProperty(oneFlowID, "name"))
	}
	
	_LeaveCriticalSection()
	
	return allFlowNames
}

xx_GetListOfFlowIDs()
{
	return _getAllFlowIds()
}


xx_getAllElementIDsOfType(p_FlowID, p_Type)
{
	_EnterCriticalSection()
	allElementIDs := _getAllElementIds(p_FlowID)

	elements:=Object()
	for oneElementIndex, oneElementID in allElementIDs
	{
		if (_getElementProperty(p_FlowID, oneElementID, "type") = p_Type)
			elements.push(oneElementID)
	}
	
	_LeaveCriticalSection()
	return elements
}

xx_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	_EnterCriticalSection()
	
	allElementIDs := _getAllElementIds(p_FlowID)

	elements:=Object()
	for oneElementIndex, oneElementID in allElementIDs
	{
		if (_getElementProperty(p_FlowID, oneElementID, "class") = p_Class)
			elements.push(oneElementID)
	}
	
	_LeaveCriticalSection()
	
	return elements
}

xx_getElementPars(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "pars")
}
xx_getElementName(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "name")
}
xx_getElementClass(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "class")
}

xx_getMyElementPars(Environment)
{
	return _getElementProperty(Environment.flowID, Environment.elementID, "pars")
}

;Manual trigger
xx_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	_EnterCriticalSection()
	
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
	_LeaveCriticalSection()
	return result
}

xx_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	_EnterCriticalSection()
	
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
	
	_LeaveCriticalSection()
	return result
}

xx_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	_EnterCriticalSection()

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
	_LeaveCriticalSection()

}

xx_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	_EnterCriticalSection()
	
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

	_LeaveCriticalSection()
}

xx_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
	params:=Object()
	params.VarsToPass:=p_Variables
	params.CallBack:=p_CallBackFunction
	
	if _existsFlow(p_FlowID)
	{
		
		;~ d(_share.temp)
		if (p_TriggerName = "")
		{
			; not trigger name specified. trigger the default trigger
			executeFlow(p_FlowID, "", params)
			return
		}
		else
		{
			; trigger name specified. Find out the ElementID of the trigger
			_EnterCriticalSection()
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
			_LeaveCriticalSection()

			if foundElementID
			{
				; Trigger now
				executeFlow(p_FlowID, foundElementID, params)
			}
			else
			{
				logger("f0", "Cannot trigger a manual trigger in flow '" _getFlowProperty(p_FlowID, "name") "'. Trigger '" p_TriggerName "' not found")
			}
		}
	}
}




;only in editor

xx_Par_Disable(p_ParameterID, p_TrueOrFalse = True)
{
}
xx_Par_Enable(p_ParameterID, p_TrueOrFalse = True)
{
}
xx_Par_SetValue(p_ParameterID, p_Value)
{
}
xx_Par_GetValue(p_ParameterID)
{
}
xx_Par_SetChoices(p_ParameterID, p_Choices)
{
}
xx_Par_SetLabel(p_ParameterID, p_Label)
{
}
xx_FirstCallOfCheckSettings(Environment)
{
}

;common functions. Available everywhere
xx_randomPhrase()
{
	return randomPhrase()
}
xx_ConvertObjToString(p_Value)
{
	if IsObject(p_Value)
		return strobj(p_Value)
}
xx_ConvertStringToObj(p_Value)
{
	if not IsObject(p_Value)
		return strobj(p_Value)
}
xx_ConvertStringToObjOrObjToString(p_Value)
{
	return strobj(p_Value)
}

xx_log(Environment, LoggingText, loglevel = 2)
{
	logger("f" loglevel, "Element " _getElementProperty(Environment.FlowID, Environment.elementID, "name") " (" Environment.elementID "): " LoggingText, _getFlowProperty(Environment.FlowID, "name"))
}

xx_GetFullPath(Environment, p_Path)
{
	path:=p_Path
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",path)
	{
		path := xx_GetWorkingDir(Environment)
	}
	return path
}

xx_GetWorkingDir(Environment)
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



; only in execution
xx_EvaluateScript(Environment, p_script)
{
}


xx_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
}


xx_TriggerInNewAHKThread_GetExportedValues(Environment)
{
}


xx_TriggerInNewAHKThread_Stop(Environment)
{
}

; only in editor
xx_assistant_windowParameter(neededInfo)
{
}

xx_assistant_MouseTracker(neededInfo)
{
}

xx_assistant_ChooseColor(neededInfo)
{
}

;common
xx_GetAhfPath()
{
	return GetAhfPath()
}

xx_isWindowsStartup()
{
	return _getShared("WindowsStartup")
}
