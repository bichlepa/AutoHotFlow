﻿;This file provides functions which can be accessed by the code inside the elements.

; only in main
xx_RegisterElementClass(p_class)
{
}

;Variable API functions.

; get a variable
xx_GetVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Get_Common(Environment, Varname, p_hidden )
}
; get a variable type
xx_getVariableType(Environment, p_Varname, p_hidden = False)
{
	return Var_GetType_Common(Environment, Varname, p_hidden )
}
; set a variable
xx_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	return Var_Set_Common(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
; delete a variable
xx_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Delete_Common(Environment, Varname, p_hidden)
}

; Get a variable location
xx_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	return Var_GetLocation_Common(Environment, Varname, p_hidden)
}

; Replace variables which are encased by percent signs
xx_replaceVariables(Environment, p_String, p_pars ="")
{
	return Var_replaceVariables_Common(Environment, String, pars)
}
; evaluate an expression
xx_EvaluateExpression(Environment, p_String)
{
	return Var_EvaluateExpression(Environment, String, true)
}
; checks a variable name, whether it is valid
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
xx_AutoEvaluateOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
}

; get list of all variables
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

; get list of all static variables
xx_GetListOfStaticVars(Environment)
{
	return Var_GetListOfStaticVars(Environment)
}
; get list of all global variables
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
xx_getEntryPoint(Environment)
{
}
xx_InstanceStop(Environment)
{
}
xx_GetMyUniqueExecutionID(Environment)
{
}
xx_GetMyUniqueTriggerID(Environment)
{
}
xx_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
}
xx_GetMyEnvironmentFromTriggerID(p_TriggerID)
{
}
xx_SetExecutionValue(Environment, p_name, p_Value)
{
}
xx_GetTriggerValue(Environment, p_name)
{
}
xx_SetTriggerValue(Environment, p_name, p_Value)
{
}
xx_GetExecutionValue(Environment, p_name)
{
}
xx_NewFunctionObject(Environment, p_ToCallFunction, params*)
{
}
xx_GetThreadCountInCurrentInstance(Environment)
{
}
xx_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
}
xx_ExecuteInNewAHKThread_Stop(Environment)
{
}
xx_trigger(Environment, data = "")
{
}
xx_enabled(Environment, Result, Message = "")
{
}
xx_disabled(Environment, Result, Message = "")
{
}


; get flow ID from the environment variable
xx_GetMyFlowID(Environment)
{
	return Environment.FlowID
}
; get flow name from the environment variable
xx_GetMyFlowName(Environment)
{
	return _getFlowProperty(Environment.FlowID, "name")
}
; get element ID from the environment variable
xx_GetMyElementID(Environment)
{
	return Environment.elementID
}

; get the flow name if the ID is known
xx_getFlowName(p_FlowID)
{
	return _getFlowProperty(p_FlowID, "name")
}

; get the flow name of given flow ID
xx_getFlowIDByName(p_FlowName)
{
	return _getFlowIdByName(p_FlowName)
}

; checks whether flow with the specified name exists
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

; checks whether flow with the specified ID exists
xx_FlowExists(p_FlowID)
{
	return _existsFlow(p_FlowID)
}

; get the flow enabling state
xx_isFlowEnabled(p_FlowID)
{
	if _getFlowProperty(p_FlowID, "enabled")
		return true
	else
		return False
}

; get the flow execution state
xx_isFlowExecuting(p_FlowID)
{
	if (_getFlowProperty(p_FlowID, "executing"))
		return true
	else
		return False
}

; enables a flow
xx_FlowEnable(p_FlowID)
{
	if xx_FlowExists(p_FlowID)
		enableFlow(p_FlowID)

}

; disables a flow
xx_FlowDisable(p_FlowID)
{
	if xx_FlowExists(p_FlowID)
		disableFlow(p_FlowID)
	
}

; stops a flow
xx_FlowStop(p_FlowID)
{
	if xx_FlowExists(p_FlowID)
		stopFlow(p_FlowID)
}

; get a list of all flow names
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

; get a list of all flow IDs
xx_GetListOfFlowIDs()
{
	return _getAllFlowIds()
}

; get all Element IDs in a flow of the specified type
xx_getAllElementIDs(p_FlowID)
{
	allElementIDs := _getAllElementIds(p_FlowID)
	return allElementIDs
}

; get all Element IDs in a flow of the specified type
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

; get all element IDs in a flow of the specified class
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

; get all parameters of an element
xx_getElementPars(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "pars")
}

; get the parameter definitions of the element
xx_getElementParsDetails(p_FlowID, p_ElementID)
{
	Environment := {flowID: p_FlowID, elementID: p_ElementID}
	elementClass := _getElementProperty(p_FlowID, p_ElementID, "class")
	return Element_getParametrizationDetails(elementClass, Environment)
}
; set the value of a element parameter
xx_setElementPar(p_FlowID, p_ElementID, p_ParameterID, p_newValue, reenableActiveTrigger = true)
{
	if (reenableActiveTrigger)
	{
		; check whether the element is a trigger and is enabled. We will need to disable and reenable it.
		elementType := _getElementProperty(p_FlowID, p_elementID, "type")
		if (elementType = "trigger")
		{
			isEnabled := xx_isTriggerEnabled(p_FlowID, p_elementID)
			if (isEnabled)
			{
				xx_triggerDisable(p_FlowID, p_elementID)
			}
		}
	}

	; set the new value in the current state
	; this is a kind of a hack. Maybe I'll find a better solution later
	currentState := _getFlowProperty(p_FlowID, "currentState")
	_setFlowProperty(p_FlowID, "states." currentState ".allElements." p_ElementID ".pars." p_ParameterID, p_newValue)
	
	; set the new value in the working state
	_setElementProperty(p_FlowID, p_ElementID, "pars." p_ParameterID, p_newValue)

	; regenerate the name of the element
	Element_updateName(p_FlowID, p_ElementID)

	; reenable trigger if it was enabled
	if (isEnabled)
	{
		xx_triggerEnable(p_FlowID, p_elementID)
	}
}

; get the name of an element
xx_getElementName(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "name")
}
; get the class of an element
xx_getElementClass(p_FlowID, p_ElementID)
{
	return _getElementProperty(p_FlowID, p_ElementID, "class")
}
; get the parameters of the current element
xx_getMyElementPars(Environment)
{
	return _getElementProperty(Environment.flowID, Environment.elementID, "pars")
}

; checks whether an element exists
xx_elementExists(p_FlowID, p_ElementID)
{
	; get all element IDs and loop through them
	allElementIDs := _getAllElementIds(p_FlowID)
	result := false
	for forelementIndex, forelementID in allElementIDs
	{
		if (forelementID = p_ElementID)
		{
			; we found the trigger, check whether it is enabled
			result := true
			break
		}
	}
	return result
}

; checks whether a trigger is enabled
xx_isTriggerEnabled(p_FlowID, p_TriggerID)
{
	_EnterCriticalSection()
	
	; get all element IDs and loop through them
	allElementIDs := _getAllElementIds(p_FlowID)
	result := false
	for forelementIndex, forelementID in allElementIDs
	{
		if (forelementID = p_TriggerID)
		{
			; we found the trigger, check whether it is enabled
			result := _getElementInfo(p_FlowID, forelementID, "enabled")
			break
		}
	}
	
	_LeaveCriticalSection()
	return result
}

; enables a single trigger
xx_triggerEnable(p_FlowID, p_TriggerID)
{
	enableOneTrigger(p_FlowID, p_TriggerID)
}

; disables a single trigger
xx_triggerDisable(p_FlowID, p_TriggerID)
{
	disableOneTrigger(p_FlowID, p_TriggerID)
}

; return the ID of the default manual trigger of a flow
xx_getDefaultManualTriggerID(p_FlowID)
{
	; get all element IDs and loop through them
	allElementIDs := _getAllElementIds(p_FlowID)
	for forelementIndex, forelementID in allElementIDs
	{
		; trigger name is set, find the trigger with that name
		if (_getElementProperty(p_FlowID, forelementID, "class") = "trigger_manual" and _getElementProperty(p_FlowID, forelementID, "defaultTrigger") = True)
		{
			return forelementID
			break
		}
	}
	; nothing found. Return nothing
	return
}

; execute the specified manual trigger
; if p_TriggerName is empty, it defaults to the default manual trigger of the flow
xx_ManualTriggerExecute(p_FlowID, p_TriggerID = "", p_Variables ="", p_CallBackFunction ="")
{
	; check first, whether flow exists
	if (not _existsFlow(p_FlowID))
	{
		logger("f0", "cannot execute manual trigger. Flow with ID " p_FlowID " does not exists.")
		return
	}
	
	if (p_TriggerID = "")
	{
		; not trigger specified. trigger the default trigger
		executeFlow(p_FlowID, "", p_Variables, {CallBack: p_CallBackFunction})
	}
	else
	{
		; trigger the specified trigger
		executeFlow(p_FlowID, p_TriggerID, p_Variables, {CallBack: p_CallBackFunction})
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
xx_Par_SetChoices(p_ParameterID, p_Choices, p_Enums = "")
{
}
xx_Par_SetLabel(p_ParameterID, p_Label)
{
}
xx_FirstCallOfCheckSettings(Environment)
{
}

; returns a translated string
xx_lang(key, params*)
{
	return lang(key, params*)
}
; returns a random phrase which can be used to create rememberable IDs
xx_randomPhrase()
{
	return randomPhrase()
}
; converts an object to a json string
xx_ConvertObjToString(p_Value, convertUnicodeChars = false)
{
	if IsObject(p_Value)
		return Jxon_Dump(p_Value, 2,, not convertUnicodeChars)
}
; convert an json string to an object
xx_ConvertStringToObj(p_Value)
{
	if not IsObject(p_Value)
		return Jxon_Load(p_Value)
}
; URI encode a string
xx_UriEncode(p_Value)
{
	return uriencode(p_Value)
}

; write a log message
; loglevel 0: only errors
; loglevel 1: major logs
; loglevel 2: more logs
; loglevel 3: all logs
xx_log(Environment, LoggingText, loglevel = 2)
{
	logger("f" loglevel, "Element " _getElementProperty(Environment.FlowID, Environment.elementID, "name") " (" Environment.elementID "): " LoggingText, _getFlowProperty(Environment.FlowID, "name"))
}

; get full file path. If path is relative, the flow working directory will be added. If it is already absolute, it will be returded unchanged.
xx_GetFullPath(Environment, p_Path)
{
	path:=p_Path
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",path)
	{
		path := xx_GetWorkingDir(Environment) "\" path
	}
	return path
}

; get working directory of the flow
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

; returns the root path of AutoHotFlow
xx_GetAhfPath()
{
	return GetAhfPath()
}

; only in execution
xx_isAHFStartup()
{
	return false
}

; only in execution
xx_isWindowsStartup()
{
	return false
}
