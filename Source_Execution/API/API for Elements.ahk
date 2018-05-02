
;This file provides functions which can be accessed while executing the elements.
;Execution thread

x_RegisterElementClass(p_class)
{
	;Only in main thread
}

;Variable API functions:
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
	EnterCriticalSection(_cs.flows)
	EnterCriticalSection(_cs.execution)

	elementClass:=_Flows[Environment.FlowID].allElements[Environment.ElementID].class
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
	
	LeaveCriticalSection(_cs.execution)
	LeaveCriticalSection(_cs.flows)
	return EvaluatedParameters
}

x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
	EnterCriticalSection(_cs.flows)
	EnterCriticalSection(_cs.execution)

	if not isobject(EvaluatedParameters)
		EvaluatedParameters:=Object()
	
	elementClass:=_Flows[Environment.FlowID].allElements[Environment.ElementID].class
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
	LeaveCriticalSection(_cs.execution)
	LeaveCriticalSection(_cs.flows)
}

x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
	EnterCriticalSection(_cs.flows)
	EnterCriticalSection(_cs.execution)
	if not (onePar)
	{
		elementClass:=_Flows[Environment.FlowID].allElements[Environment.ElementID].class
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
	LeaveCriticalSection(_cs.execution)
	LeaveCriticalSection(_cs.flows)
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
	return objfullyclone(_execution.instances[Environment.InstanceID].InstanceVars)
}
x_ImportInstanceVars(Environment, p_VarsToImport)
{
	for onevarName, oneVar in p_VarsToImport
	{
		InstanceVariable_Set(Environment,onevarName,oneVar)
	}
	return Var_GetListOfInstanceVars(Environment)
}



;execution

x_finish(Environment, p_Result, p_Message = "")
{
	finishExecutionOfElement(Environment, p_Result, p_Message)
	
}


x_getEntryPoint(Environment) ;For loops
{
	return Environment.ElementEntryPoint
}


x_InstanceStop(Environment)
{
	stopInstance(_execution.Instances[Environment.instanceID])
}


x_GetMyUniqueExecutionID(Environment)
{
	return Environment.UniqueID
}

x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
	global
	return global_AllExecutionIDs[p_ExecutionID].environment
}

x_SetExecutionValue(Environment, p_name, p_Value)
{
	EnterCriticalSection(_cs.execution)
	Environment.ElementExecutionValues[p_name]:=p_value
	LeaveCriticalSection(_cs.execution)
}
x_GetExecutionValue(Environment, p_name)
{
	EnterCriticalSection(_cs.execution)
	retval:=Environment.ElementExecutionValues[p_name]
	LeaveCriticalSection(_cs.execution)
	return retval
}

x_NewExecutionFunctionObject(Environment, p_ToCallFunction, params*)
{
	EnterCriticalSection(_cs.execution)
	oneFunctionObject:=new Class_FunctionObject(Environment, p_ToCallFunction, params*)
	global_AllExecutionIDs[Environment.uniqueID].ExecutionFunctionObjects[p_ToCallFunction]:=oneFunctionObject
	LeaveCriticalSection(_cs.execution)
	return oneFunctionObject
}


; Function object for function x_NewExecutionFunctionObject
class Class_FunctionObject
{
    __New(Environment, ToCallFunction, params*) 
	{
		;~ d(params, "ih")
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
	EnterCriticalSection(_cs.execution)
	count:=0
	for oneinstanceID, oneInstance in _execution.Instances
	{
		if (oneInstance.ID = Environment.InstanceID)
		{
			count++
		}
	}
	LeaveCriticalSection(_cs.execution)
	return count
}



;exeuction in other ahk thread
x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	global global_AllExecutionIDs

	EnterCriticalSection(_cs.execution)

	if not isobject(global_AllExecutionIDs[Environment.uniqueID])
		global_AllExecutionIDs[Environment.uniqueID]:=object()
	global_AllExecutionIDs[Environment.uniqueID].ExeInNewThread:=object()
	global_AllExecutionIDs[Environment.uniqueID].ExeInNewThread.functionObject:=p_functionObject
	
	_share.temp[Environment.uniqueID]:= Object()
	_share.temp[Environment.uniqueID].sharedObject := CriticalObject()
	_share.temp[Environment.uniqueID].sharedObject.varsToImport:=p_VarsToImport
	_share.temp[Environment.uniqueID].sharedObject.varsToExport:=p_VarsToExport
	_share.temp[Environment.uniqueID].sharedObject.varsExported:=Object()
	;~ d(_share.temp[Environment.uniqueID])
	;~ d(environment)
	preCode := "ahf_uniqueID :=""" Environment.uniqueID """`n"
	preCode .= "ahf_sharedObject := CriticalObject(" (&_share.temp[Environment.uniqueID].sharedObject) ")`n"
	preCode .= "onexit, ahf_onexit`n"
	preCode .= "ahf_parentAHKThread := AhkExported()`n"
	preCode .= "for ahf_varname, ahf_varvalue in ahf_sharedObject.varsToImport`n"
	preCode .= "{`n"
	preCode .= "  %ahf_varname%:=ahf_VarValue`n"
	;~ preCode .= "  msgbox, %ahf_varname% - %ahf_VarValue%`n"
	preCode .= "}`n"

	postcode := "exitapp`n"
	postcode .= "ahf_onexit:`n"
	postcode .= "for ahf_varindex, ahf_varname in ahf_sharedObject.varsToExport`n{`n  ahf_sharedObject.varsExported[ahf_varname]:=%ahf_varname%`n}`n"
	;~ postcode .= "msgbox %ahf_uniqueID%`n"
	postcode .= "ahf_parentAHKThread.ahkFunction(""API_Execution_externalFlowFinish"", ahf_uniqueID)`n"
	postcode .= "exitapp"
	
	
	LeaveCriticalSection(_cs.execution)
	;~ d("`n" preCode "`n" p_Code "`n" postCode)
	AhkThread("`n" preCode "`n" p_Code "`n" postCode)
	
}

ExecuteInNewAHKThread_finishedExecution(p_ExecutionID) ;Not an api function
{
	global global_AllExecutionIDs
	EnterCriticalSection(_cs.execution)

	Environment:=x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
	functionObject:=global_AllExecutionIDs[Environment.uniqueID].ExeInNewThread.functionObject
	varsExported:=_share.temp[Environment.uniqueID].sharedObject.varsExported

	LeaveCriticalSection(_cs.execution)
	%functionObject%(varsExported)
}
;exeuction of a trigger in other ahk thread
x_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
	global _share, global_AllActiveTriggerIDs
	EnterCriticalSection(_cs.execution)

	if not isobject(global_AllActiveTriggerIDs[Environment.uniqueID])
		global_AllActiveTriggerIDs[Environment.uniqueID]:=object()
	global_AllActiveTriggerIDs[Environment.uniqueID].ExeInNewThread:=object()
	global_AllActiveTriggerIDs[Environment.uniqueID].environment:=Environment
	
	_share.temp[Environment.uniqueID]:= Object()
	_share.temp[Environment.uniqueID].sharedObject := CriticalObject()
	_share.temp[Environment.uniqueID].sharedObject.varsToImport:=p_VarsToImport
	_share.temp[Environment.uniqueID].sharedObject.varsToExport:=p_VarsToExport
	_share.temp[Environment.uniqueID].sharedObject.varsExported:=Object()
	;~ d(_share.temp[Environment.uniqueID])
	preCode := "ahf_uniqueID :=""" Environment.uniqueID """`n"
	preCode .= "ahf_sharedObject := CriticalObject(" (&_share.temp[Environment.uniqueID].sharedObject) ")`n"
	preCode .= "ahf_parentAHKThread := AhkExported()`n"
	preCode .= "for ahf_varname, ahf_varvalue in ahf_sharedObject.varsToImport`n"
	preCode .= "{`n"
	preCode .= "  %ahf_varname%:=ahf_VarValue`n"
	;~ preCode .= "  msgbox, %ahf_varname% - %ahf_VarValue%`n"
	preCode .= "}`n"
	

	postcode := "exitapp`n"
	postcode .= "x_trigger()`n"
	postcode .= "{`n"
	postcode .= "global`n"
	postcode .= "for ahf_varindex, ahf_varname in ahf_sharedObject.varsToExport`n{`n  ahf_sharedObject.varsExported[ahf_varname]:=%ahf_varname%`n}`n"
	postcode .= "ahf_parentAHKThread.ahkFunction(""API_Execution_externalTrigger"", ahf_uniqueID)`n"
	postcode .= "}`n"
		
	LeaveCriticalSection(_cs.execution)
	;~ d("`n" preCode "`n" p_Code "`n" postCode)
	AHKThreadID:=AhkThread("`n" preCode "`n" p_Code "`n" postCode)

	EnterCriticalSection(_cs.execution)
	global_AllActiveTriggerIDs[Environment.uniqueID].ExeInNewThread.AHKThreadID:=AHKThreadID
	LeaveCriticalSection(_cs.execution)
	
}
x_TriggerInNewAHKThread_Stop(Environment)
{
	EnterCriticalSection(_cs.execution)
	AHKThreadID:=global_AllActiveTriggerIDs[Environment.uniqueID].ExeInNewThread.AHKThreadID
	LeaveCriticalSection(_cs.execution)
	ahkthread_release(global_AllActiveTriggerIDs[Environment.uniqueID].ExeInNewThread.AHKThreadID)
}
ExecuteInNewAHKThread_trigger(p_uniqueID) ;Not an api function
{
	global _share
	EnterCriticalSection(_cs.execution)
	Environment:=global_AllActiveTriggerIDs[p_uniqueID].environment
	;~ d(Environment, "öiohöio")
	Environment.varsExportedFromExternalThread:=_share.temp[Environment.uniqueID].sharedObject.varsExported
	ElementClass:=Environment.ElementClass

	LeaveCriticalSection(_cs.execution)
	x_trigger(Environment)
}
x_TriggerInNewAHKThread_GetExportedValues(Environment)
{
	EnterCriticalSection(_cs.execution)
	retval:=Environment.varsExportedFromExternalThread
	LeaveCriticalSection(_cs.execution)
	return Environment.varsExportedFromExternalThread
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
	return Environment.FlowID
}
x_GetMyFlowName(Environment)
{
	EnterCriticalSection(_cs.flows)
	retval:=_flows[Environment.FlowID].name
	LeaveCriticalSection(_cs.flows)
	return retval
}

x_GetMyElementID(Environment)
{
	return Environment.elementID
}


x_getFlowIDByName(p_FlowName)
{
	EnterCriticalSection(_cs.flows)
	
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			retval:= forFlowID
		}
	}
	
	LeaveCriticalSection(_cs.flows)
	return retval
}

x_FlowExistsByName(p_FlowName)
{
	EnterCriticalSection(_cs.flows)
	
	retval:=false
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			retval:= True
		}
	}
	
	LeaveCriticalSection(_cs.flows)
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
	;Search for all flowNames
	EnterCriticalSection(_cs.flows)
	
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlow.name)
	}
	
	LeaveCriticalSection(_cs.flows)
	return choices
}

x_GetListOfFlowIDs()
{
	;Search for all flowNames
	EnterCriticalSection(_cs.flows)
	
	choices:=object()
	for oneFlowID, oneFlow in _flows
	{
		choices.push(oneFlowID)
	}
	
	LeaveCriticalSection(_cs.flows)
	return choices
}





x_getAllElementIDsOfType(p_FlowID, p_Type)
{
	EnterCriticalSection(_cs.flows)
	
	elements:=Object()
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.type = p_Type)
			elements.push(oneElementID)
	}
	
	LeaveCriticalSection(_cs.flows)
	return elements
}

x_getAllElementIDsOfClass(p_FlowID, p_Class)
{
	EnterCriticalSection(_cs.flows)
	
	elements:=Object()
	for oneElementID, oneElement in _flows[p_FlowID].allElements
	{
		if (oneElement.class = p_Class)
			elements.push(oneElementID)
	}
	
	LeaveCriticalSection(_cs.flows)
	return elements
}

x_getElementPars(p_FlowID, p_ElementID)
{
	EnterCriticalSection(_cs.flows)
	retval:=objfullyClone(_flows[p_FlowID].allElements[p_ElementID].pars)
	LeaveCriticalSection(_cs.flows)
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



;Manual trigger
x_ManualTriggerExist(p_FlowID, p_TriggerName = "")
{
	EnterCriticalSection(_cs.flows)
	
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
	LeaveCriticalSection(_cs.flows)
	return result
}

x_isManualTriggerEnabled(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs.flows)
	
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
	
	LeaveCriticalSection(_cs.flows)
	return result
}

x_ManualTriggerEnable(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs.flows)
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
	LeaveCriticalSection(_cs.flows)

}

x_ManualTriggerDisable(p_FlowID, p_TriggerName="")
{
	EnterCriticalSection(_cs.flows)
	
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

	LeaveCriticalSection(_cs.flows)

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
			startFlow(_flows[p_FlowID], "", params)
			return
		}
		else
		{
			;~ d(p_FlowName " - " p_TriggerName)
			EnterCriticalSection(_cs.flows)
			foundElementID:=""
			for forelementID, forelement in _flows[p_FlowID].allElements
			{
				;~ d(forelement, p_TriggerName)
				if forelement.class = "trigger_Manual"
				{
					if (forelement.pars.id = p_TriggerName)
					{
						foundElement:=forelement
						break
					}
				}
			}
			LeaveCriticalSection(_cs.flows)

			if foundElement
			{
				startFlow(_flows[p_FlowID], foundElement, params)
			}
			else
			{
				;todo: log error
			}
		}
	}
}






;While editing (not supported here)

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

;assistants
x_assistant_windowParameter(neededInfo)
{
}
x_assistant_MouseTracker(neededInfo)
{
}
x_assistant_ChooseColor(neededInfo)
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
		path := x_GetWorkingDir(Environment) "\" path
	}
	return path
}

x_GetWorkingDir(Environment)
{
	EnterCriticalSection(_cs.flows)
	if (_Flows[Environment.FlowID].flowsettings.DefaultWorkingDir)
	{
		retval:= _settings.FlowWorkingDir
	}
	else
	{
		retval:= _Flows[Environment.FlowID].flowsettings.workingdir
	}
	LeaveCriticalSection(_cs.flows)
	return retval
}

x_GetAhfPath()
{
	return GetAhfPath()
}

x_isWindowsStartup()
{
	return _share.WindowsStartup
}