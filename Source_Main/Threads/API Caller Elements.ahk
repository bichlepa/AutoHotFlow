;This file provides functions which can be accessed while executing the elements.
;main thread

;Register Element classes
x_RegisterElementClass(p_class)
{
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

;execution (not supported here)

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
	return _flows[Environment.FlowID].name
}

x_GetMyElementID(Environment)
{
	return Environment.elementID
}

x_getFlowIDByName(p_FlowName)
{
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
	return objfullyClone(_flows[p_FlowID].allElements[p_ElementID].pars)
}
x_getElementName(p_FlowID, p_ElementID)
{
	return _flows[p_FlowID].allElements[p_ElementID].name
}
x_getElementClass(p_FlowID, p_ElementID)
{
	return _flows[p_FlowID].allElements[p_ElementID].class
}


;Manual trigger
x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
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

}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
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

}

x_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
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
			executeFlow(p_FlowID, "", randomnumber)
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
						executeFlow(p_FlowID, forelementID, randomnumber)
						return
					}
				}
			}
		}
	}
}





;while editing (not supported here)

x_Par_Disable(p_ParameterID, p_TrueOrFalse = True)
{
}
x_Par_Enable(p_ParameterID, p_TrueOrFalse = True)
{
}
x_Par_SetValue(p_ParameterID, p_Value)
{
}
x_Par_GetValue(p_ParameterID)
{
}
x_Par_SetChoices(p_ParameterID, p_Choices)
{
}
x_Par_SetLabel(p_ParameterID, p_Label)
{
}
x_FirstCallOfCheckSettings(Environment)
{
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
}


x_assistant_MouseTracker(neededInfo)
{
}
x_assistant_ChooseColor(neededInfo)
{
}


x_GetAhfPath()
{
	return GetAhfPath()
}

x_isWindowsStartup()
{
	return _share.WindowsStartup
}