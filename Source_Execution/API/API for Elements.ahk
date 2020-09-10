
;This file provides functions which can be accessed while executing the elements.
;Execution thread

x_RegisterElementClass(p_class)
{
	;Only in main thread
}

;Variable API functions: different in execution
x_GetVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Get(Environment, p_Varname, p_hidden )
}
x_getVariableType(Environment, p_Varname, p_hidden = False)
{
	return Var_GetType(Environment, p_Varname, p_hidden )
}
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	return Var_Set(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
x_DeleteVariable(Environment, p_Varname, p_hidden = False)
{
	return Var_Delete(Environment, p_Varname, p_hidden)
}

x_GetVariableLocation(Environment, p_Varname, p_hidden = False)
{
	return Var_GetLocation(Environment, p_Varname, p_hidden)
}

x_replaceVariables(Environment, p_String, p_pars ="")
{
	return Var_replaceVariables(Environment, p_String, p_pars)
}
x_EvaluateExpression(Environment, p_String)
{
	return Var_EvaluateExpression(Environment, p_String, "Var_Get", "Var_Set")
}

x_EvaluateScript(Environment, p_script)
{
	var_evaluateScript(Environment, p_script, "Var_Get", "Var_Set")
}


x_CheckVariableName(p_VarName)
{
	return Var_CheckName(p_VarName)
}

x_AutoEvaluateParameters(Environment, ElementParameters, p_skipList = "")
{
	EnterCriticalSection(_cs_shared)

	elementClass:=_getElementProperty(Environment.FlowID, Environment.ElementID, "class")
	ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
	EvaluatedParameters:=Object()
	
	for oneParIndex, onePar in ParametrationDetails
	{
		if (not onePar.id)
		{
			continue
		}
		if (not isObject(onePar.id))
			parIDs:=[onePar.id]
		else
			parIDs:=onePar.id
		
		for oneIndex, oneParID in parIDs
		{
			;Label and button cannot be evaluated
			if (onePar.type = "label" or onPar.type = "Button")
			{
				continue
			}
			
			;skip parameter if it is in the passed skip list
			skipThis:=false
			for oneSkipParIndex, oneSkipParID in p_skipList
			{
				if (oneSkipParID = oneParID)
				{
					continue
				}
			}
			
			x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
			if (EvaluatedParameters._error)
			{
				;Stop evaluating if an error occurs
				break
			}
			
		}
	}
	
	LeaveCriticalSection(_cs_shared)
	return EvaluatedParameters
}

x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
	EnterCriticalSection(_cs_shared)

	if not isobject(EvaluatedParameters)
		EvaluatedParameters:=Object()
	
	elementClass:=_getElementProperty(Environment.FlowID, Environment.ElementID, "class")
	ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
	
	for oneParIndex, onePar in ParametrationDetails
	{
		if (not onePar.id)
		{
			continue
		}
		if (not isObject(onePar.id))
			parIDs:=[onePar.id]
		else
			parIDs:=onePar.id
		
		for oneIndex, oneParID in parIDs
		{
			;Label and button cannot be evaluated
			if (onePar.type = "label" or onPar.type = "Button")
			{
				continue
			}

			for onePartoEvalIndex, onePartoEval in p_ParametersToEvaluate
			{
				if (onePartoEval = oneParID)
				{
					x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
					break
				}
			}
			;Stop evaluating if an error occurs
			if (EvaluatedParameters._error)
				break
		}
	}
	LeaveCriticalSection(_cs_shared)
}

x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
	EnterCriticalSection(_cs_shared)
	if not (onePar)
	{
		elementClass:=_getElementProperty(Environment.FlowID, Environment.ElementID, "class")
		ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
		for oneParIndex, onePar2 in ParametrationDetails
		{
			if (not onePar2.id)
			{
				continue
			}
			if (not isObject(onePar2.id))
				parIDs:=[onePar2.id]
			else
				parIDs:=onePar2.id
			
			
			for oneIndex, oneParID2 in parIDs
			{
				if (oneParID = oneParID2)
				{
					onePar := onePar2
					break
				}
			}
			if (onePar)
				break
		}
	}
	
	
	if (IsObject(onePar.content))
	{
		oneParContent:=ElementParameters[onePar.contentID]
	}
	else
	{
		oneParContent:=onePar.content
	}
	
	if (onePar.type = "file" or onepar.type = "folder")
	{
		result := x_replaceVariables(Environment,ElementParameters[oneParID])
		if (onePar.WarnIfEmpty)
		{
			if (result = "")
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("String '%1%' is empty", ElementParameters[oneParID])
			}
		}
		EvaluatedParameters[oneParID]:=x_GetFullPath(Environment, result)
	}
	else
	{
		if (oneParContent = "string")
		{
			result := x_replaceVariables(Environment,ElementParameters[oneParID])
			if (onePar.WarnIfEmpty)
			{
				if (result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("String '%1%' is empty", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID]:=result
		}
		else if (oneParContent = "expression" or oneParContent = "number")
		{
			evRes := x_evaluateExpression(Environment,ElementParameters[oneParID])
			if (evRes.error)
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("An error occured while parsing expression '%1%'", ElementParameters[oneParID]) "`n`n" evRes.error
			}
			if (onePar.WarnIfEmpty)
			{
				if (evRes.result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Result of expression '%1%' is empty", ElementParameters[oneParID])
				}
			}
			if (oneParContent = "number")
			{
				temp:=evRes.result
				if temp is not number
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Result of expression '%1%' is not a number", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID] := evRes.result
		}
		else if (oneParContent = "VariableName")
		{
			result := x_replaceVariables(Environment, ElementParameters[oneParID])
			if not x_CheckVariableName(result)
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("%1% is not valid", lang("Variable name '%1%'", result))
			}
			EvaluatedParameters[oneParID] := result
		}
		else if (oneParContent = "RawString")
		{
			result := ElementParameters[oneParID]
			if (onePar.WarnIfEmpty)
			{
				if (result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Parameter '%1%' is empty", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID] := result
		}
		else
		{
			result := ElementParameters[oneParID]
			if (onePar.WarnIfEmpty)
			{
				if (result = "")
				{
					EvaluatedParameters._error := true
					EvaluatedParameters._errorMessage := lang("Parameter '%1%' is empty", ElementParameters[oneParID])
				}
			}
			EvaluatedParameters[oneParID] := result
		}
	}
	LeaveCriticalSection(_cs_shared)
	return EvaluatedParameters
}

x_GetListOfAllVars(Environment)
{
	return Var_GetListOfAllVars(Environment)
}
x_GetListOfLoopVars(Environment)
{
	return Var_GetListOfLoopVars(Environment)
}
x_GetListOfThreadVars(Environment)
{
	return Var_GetListOfThreadVars(Environment)
}
x_GetListOfInstanceVars(Environment)
{
	return Var_GetListOfInstanceVars(Environment)
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
	return _getInstanceProperty(Environment.InstanceID, "InstanceVars")
}
x_ImportInstanceVars(Environment, p_VarsToImport)
{
	for onevarName, oneVar in p_VarsToImport
	{
		InstanceVariable_Set(Environment, onevarName, oneVar)
	}
	return Var_GetListOfInstanceVars(Environment)
}


x_finish(Environment, p_Result, p_Message = "")
{
	finishExecutionOfElement(Environment.InstanceID, Environment.ThreadID, p_Result, p_Message)
	
}


x_getEntryPoint(Environment)
{
	return _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "ElementEntryPoint")
}


x_InstanceStop(Environment)
{
	stopInstance(Environment.instanceID)
}


x_GetMyUniqueExecutionID(Environment)
{
	return _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "UniqueID")
}

x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
	global
	return global_AllExecutionIDs[p_ExecutionID].environment
}

x_SetExecutionValue(Environment, p_name, p_Value)
{
	EnterCriticalSection(_cs_shared)
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "ElementExecutionValues." p_name, p_value, false)
	LeaveCriticalSection(_cs_shared)
}
x_GetExecutionValue(Environment, p_name)
{
	EnterCriticalSection(_cs_shared)
	retval := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "ElementExecutionValues." p_name, false)
	LeaveCriticalSection(_cs_shared)
	return retval
}

x_NewExecutionFunctionObject(Environment, p_ToCallFunction, params*)
{
	EnterCriticalSection(_cs_shared)
	oneFunctionObject:=new Class_FunctionObject(Environment, p_ToCallFunction, params*)
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")
	global_AllExecutionIDs[uniqueID].ExecutionFunctionObjects[p_ToCallFunction]:=oneFunctionObject
	LeaveCriticalSection(_cs_shared)
	return oneFunctionObject
}


; Function object for function x_NewExecutionFunctionObject
class Class_FunctionObject
{
    __New(Environment, ToCallFunction, params*) 
	{
        this.Environment := Environment
        this.FunctionObject := ObjBindMethod(this, Call)
		this.ToCallFunction := ToCallFunction
		this.params := params
		return this.FunctionObject
    }
   
    Call(args*) 
	{
        ;~ d(args, "adf")
		if not isobject(args)
			args:=Object()
		for oneparindex, onepar in this.params
		{
			args.push(onepar)
		}
		ToCallFunction:=this.ToCallFunction
		%ToCallFunction%(this.Environment, args*)
    }
	
	 __Call(method, args*) {
        if (method = "")  ; For %fn%() or fn.()
            return this.Call(args*)
        if (IsObject(method))  ; If this function object is being used as a method.
            return this.Call(method, args*)
    }
	
	__delete()
	{
		MsgBox Class_FunctionObject __delete
	}
}


x_GetThreadCountInCurrentInstance(Environment)
{
	EnterCriticalSection(_cs_shared)

	allThreadIDs := _getAllThreadIds(Environment.InstanceID)
	count:=0
	for oneinstanceIndex, oneInstanceID in allThreadIDs
	{
		if (oneInstanceID = Environment.InstanceID)
		{
			count++
		}
	}
	LeaveCriticalSection(_cs_shared)
	return count
}



;exeuction in other ahk thread
x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	global global_AllExecutionIDs

	EnterCriticalSection(_cs_shared)
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")

	if not isobject(global_AllExecutionIDs[uniqueID])
		global_AllExecutionIDs[uniqueID]:=object()
	global_AllExecutionIDs[uniqueID].ExeInNewThread:=object()
	global_AllExecutionIDs[uniqueID].ExeInNewThread.functionObject:=p_functionObject
	
	sharedObject:=CriticalObject()
	sharedObject.varsToImport:=p_VarsToImport
	sharedObject.varsToExport:=p_VarsToExport
	sharedObject.varsExported:=Object()
	_setSharedProperty("temp." uniqueID, {sharedObject: sharedObject}, false)
	
	preCode := "ahf_uniqueID :=""" uniqueID """`n"
	preCode .= "ahf_cs_shared := " _cs_shared "`n"
	preCode .= "ahf_sharedObject := CriticalObject(" (&sharedObject) ")`n"
	preCode .= "onexit, ahf_onexit`n"
	preCode .= "ahf_parentAHKThread := AhkExported()`n"
	preCode .= "EnterCriticalSection(ahf_cs_shared)`n"
	preCode .= "for ahf_varname, ahf_varvalue in ahf_sharedObject.varsToImport`n"
	preCode .= "{`n"
	preCode .= "  %ahf_varname%:=ahf_VarValue`n"
	preCode .= "}`n"
	preCode .= "LeaveCriticalSection(ahf_cs_shared)`n"

	postcode := "exitapp`n"
	postcode .= "ahf_onexit:`n"
	postcode .= "EnterCriticalSection(ahf_cs_shared)`n"
	postcode .= "for ahf_varindex, ahf_varname in ahf_sharedObject.varsToExport`n{`n  ahf_sharedObject.varsExported[ahf_varname]:=%ahf_varname%`n}`n"
	postcode .= "LeaveCriticalSection(ahf_cs_shared)`n"
	postcode .= "ahf_parentAHKThread.ahkFunction(""API_Execution_externalFlowFinish"", ahf_uniqueID)`n"
	postcode .= "exitapp"
	
	
	LeaveCriticalSection(_cs_shared)
	;~ d("`n" preCode "`n" p_Code "`n" postCode)
	AhkThread("`n" preCode "`n" p_Code "`n" postCode)
	
}

ExecuteInNewAHKThread_finishedExecution(p_ExecutionID) ;Not an api function
{
	global global_AllExecutionIDs
	EnterCriticalSection(_cs_shared)

	Environment:=x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")
	functionObject:=global_AllExecutionIDs[uniqueID].ExeInNewThread.functionObject
	varsExported:=_getSharedProperty("temp." uniqueID ".sharedObject.varsExported")

	LeaveCriticalSection(_cs_shared)
	%functionObject%(varsExported)
}

;exeuction of a trigger in other ahk thread
x_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
	global global_AllActiveTriggerIDs
	EnterCriticalSection(_cs_shared)
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")

	if not isobject(global_AllActiveTriggerIDs[uniqueID])
		global_AllActiveTriggerIDs[uniqueID]:=object()
	global_AllActiveTriggerIDs[uniqueID].ExeInNewThread:=object()
	global_AllActiveTriggerIDs[uniqueID].environment:=Environment
	
	sharedObject:=CriticalObject()
	sharedObject.varsToImport:=p_VarsToImport
	sharedObject.varsToExport:=p_VarsToExport
	sharedObject.varsExported:=Object()
	_setSharedProperty("temp." uniqueID, {sharedObject: sharedObject}, false)
	
	preCode := "ahf_uniqueID :=""" uniqueID """`n"
	preCode .= "ahf_cs_shared := " _cs_shared "`n"
	preCode .= "ahf_sharedObject := CriticalObject(" (&sharedObject) ")`n"
	preCode .= "ahf_parentAHKThread := AhkExported()`n"
	preCode .= "EnterCriticalSection(ahf_cs_shared)`n"
	preCode .= "for ahf_varname, ahf_varvalue in ahf_sharedObject.varsToImport`n"
	preCode .= "{`n"
	preCode .= "  %ahf_varname%:=ahf_VarValue`n"
	preCode .= "}`n"
	preCode .= "LeaveCriticalSection(ahf_cs_shared)`n"
	

	postcode := "exitapp`n"
	postcode .= "x_trigger()`n"
	postcode .= "{`n"
	postcode .= "global`n"
	postcode .= "EnterCriticalSection(ahf_cs_shared)`n"
	postcode .= "for ahf_varindex, ahf_varname in ahf_sharedObject.varsToExport`n{`n  ahf_sharedObject.varsExported[ahf_varname]:=%ahf_varname%`n}`n"
	postcode .= "LeaveCriticalSection(ahf_cs_shared)`n"
	postcode .= "ahf_parentAHKThread.ahkFunction(""API_Execution_externalTrigger"", ahf_uniqueID)`n"
	postcode .= "}`n"
		
	LeaveCriticalSection(_cs_shared)
	AHKThreadID:=AhkThread("`n" preCode "`n" p_Code "`n" postCode)

	global_AllActiveTriggerIDs[uniqueID].ExeInNewThread.AHKThreadID:=AHKThreadID
	
}
x_TriggerInNewAHKThread_Stop(Environment)
{
	EnterCriticalSection(_cs_shared)
	uniqueID := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "uniqueID")
	AHKThreadID:=global_AllActiveTriggerIDs[uniqueID].ExeInNewThread.AHKThreadID
	LeaveCriticalSection(_cs_shared)
	ahkthread_release(global_AllActiveTriggerIDs[uniqueID].ExeInNewThread.AHKThreadID)
}
ExecuteInNewAHKThread_trigger(p_uniqueID) ;Not an api function
{
	EnterCriticalSection(_cs_shared)
	Environment:=global_AllActiveTriggerIDs[p_uniqueID].environment
	varsExportedFromExternalThread :=_getSharedProperty("temp." p_uniqueID ".sharedObject.varsExported")
	_setThreadProperty(Environment.InstanceID, Environment.ThreadID, "varsExportedFromExternalThread", varsExportedFromExternalThread)

	LeaveCriticalSection(_cs_shared)
	x_trigger(Environment)
}
x_TriggerInNewAHKThread_GetExportedValues(Environment)
{
	EnterCriticalSection(_cs_shared)
	retval := _getThreadProperty(Environment.InstanceID, Environment.ThreadID, "varsExportedFromExternalThread")
	LeaveCriticalSection(_cs_shared)
	return retval
}





;For triggers
x_trigger(Environment)
{
	newInstance(Environment)
}

x_enabled(Environment, Result, Message = "")
{
	saveResultOfTriggerEnabling(Environment, Result, Message)
}
x_disabled(Environment, Result, Message = "")
{
	saveResultOfTriggerDisabling(Environment, Result, Message)
}



;get some information

x_GetMyFlowID(Environment)
{
	return xx_GetMyFlowID(Environment)
}
x_GetMyFlowName(Environment)
{
	return xx_GetMyFlowName(Environment)
}

x_GetMyElementID(Environment)
{
	return xx_GetMyElementID(Environment)
}

x_getFlowIDByName(p_FlowName)
{
	return xx_getFlowIDByName(p_FlowName)
}



x_FlowExistsByName(p_FlowName)
{
	return xx_FlowExistsByName(p_FlowName)
}

x_FlowExists(p_FlowID)
{
	return xx_FlowExists(p_FlowID)
}


x_isFlowEnabled(p_FlowID)
{
	return xx_isFlowEnabled(p_FlowID)
}



x_isFlowExecuting(p_FlowID)
{
	return xx_isFlowExecuting(p_FlowID)
}


x_FlowEnable(p_FlowID)
{
	return xx_FlowEnable(p_FlowID)

}


x_FlowDisable(p_FlowID)
{
	return xx_FlowDisable(p_FlowID)
	
}

x_FlowStop(p_FlowID)
{
	return xx_FlowStop(p_FlowID)
}


x_GetListOfFlowNames()
{
	return xx_GetListOfFlowNames()
}

x_GetListOfFlowIDs()
{
	return xx_GetListOfFlowIDs()
}


x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	return xx_getAllElementIDsOfType(p_FlowID, p_Type)
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	return xx_getAllElementIDsOfClass(p_FlowID, p_Class)
}

x_getElementPars(p_FlowID, p_ElementID)
{
	return xx_getElementPars(p_FlowID, p_ElementID)
}
x_getElementName(p_FlowID, p_ElementID)
{
	return xx_getElementName(p_FlowID, p_ElementID)
}
x_getElementClass(p_FlowID, p_ElementID)
{
	return xx_getElementClass(p_FlowID, p_ElementID)
}

x_getMyElementPars(Environment)
{
	return xx_getMyElementPars(Environment)
}


x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	return xx_ManualTriggerExist(p_FlowID, p_TriggerName)
}

x_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	return xx_isManualTriggerEnabled(p_FlowID, p_TriggerName)
}

x_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	return xx_ManualTriggerEnable(p_FlowID, p_TriggerName)
}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	return xx_ManualTriggerDisable(p_FlowID, p_TriggerName)
}

x_ManualTriggerExecute(p_FlowID, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
{
	return xx_ManualTriggerExecute(p_FlowID, p_TriggerName, p_Variables, p_CallBackFunction)
}
executeFlow(p_FlowID, p_TriggerID, p_params)
{
	startFlow(p_FlowID, p_TriggerID, p_params)
}



x_Par_Disable(p_ParameterID, p_TrueOrFalse = True)
{
	return xx_Par_Disable(p_ParameterID, p_TrueOrFalse)
}
x_Par_Enable(p_ParameterID, p_TrueOrFalse = True)
{
	return xx_Par_Enable(p_ParameterID, p_TrueOrFalse)
}
x_Par_SetValue(p_ParameterID, p_Value)
{
	return xx_Par_SetValue(p_ParameterID, p_Value)
}
x_Par_GetValue(p_ParameterID)
{
	return xx_Par_GetValue(p_ParameterID)
}
x_Par_SetChoices(p_ParameterID, p_Choices)
{
	return xx_Par_SetChoices(p_ParameterID, p_Choices)
}
x_Par_SetLabel(p_ParameterID, p_Label)
{
	return xx_Par_SetLabel(p_ParameterID, p_Label)
}
x_FirstCallOfCheckSettings(Environment)
{
	return xx_FirstCallOfCheckSettings(Environment)
}

x_randomPhrase()
{
	return xx_randomPhrase()
}
x_ConvertObjToString(p_Value)
{
	return xx_ConvertObjToString(p_Value)
}
x_ConvertStringToObj(p_Value)
{
	return xx_ConvertStringToObj(p_Value)
}
x_ConvertStringToObjOrObjToString(p_Value)
{
	return xx_ConvertStringToObjOrObjToString(p_Value)
}



x_log(Environment, LoggingText, loglevel = 2)
{
	return xx_log(Environment, LoggingText, loglevel)
}

x_GetFullPath(Environment, p_Path)
{
	return xx_GetFullPath(Environment, p_Path)
}

x_GetWorkingDir(Environment)
{
	return xx_GetWorkingDir(Environment)
}


x_assistant_windowParameter(neededInfo)
{
	return xx_assistant_windowParameter(neededInfo)
}

x_assistant_MouseTracker(neededInfo)
{
	return xx_assistant_MouseTracker(neededInfo)
}

x_assistant_ChooseColor(neededInfo)
{
	return xx_assistant_ChooseColor(neededInfo)
}


x_GetAhfPath()
{
	return xx_GetAhfPath()
}

x_isWindowsStartup()
{
	return xx_isWindowsStartup()
}