
;This file provides functions which can be accessed while executing the elements.
;Execution thread


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
	elementClass:=_Flows[Environment.FlowID].allElements[Environment.ElementID].class
	ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
	EvaluatedParameters:=Object()
	
	;~ d(Environment)
	;~ d(ParametrationDetails, "ParametrationDetails "  elementClass)
	
	for oneParIndex, onePar in ParametrationDetails
	{
	;~ d(onePar, "onePar")
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
			;~ d(oneParID, "oneParID")
			if (onePar.type = "label" or onPar.type = "Button")
			{
				continue
			}
			
			skipThis:=false
			for oneSkipParIndex, oneSkipParID in p_skipList
			{
				if (oneSkipParID = oneParID)
				{
					skipThis:=true
				}
			}
			if skipThis
				continue
			
			x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
			if (EvaluatedParameters._error)
				return EvaluatedParameters
			
		}
	}
	
	return EvaluatedParameters
}

x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, p_ParametersToEvaluate)
{
	if not isobject(EvaluatedParameters)
		EvaluatedParameters:=Object()
	
	elementClass:=_Flows[Environment.FlowID].allElements[Environment.ElementID].class
	ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
	
	for oneParIndex, onePar in ParametrationDetails
	{
	;~ d(onePar, "onePar")
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
			;~ d(oneParID, "oneParID")
			if (onePar.type = "label" or onPar.type = "Button")
			{
				continue
			}
			for onePartoEvalIndex, onePartoEval in p_ParametersToEvaluate
			{
				if (onePartoEval = oneParID)
				{
					;~ d(EvaluatedParameters, oneParID)
					x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar)
					;~ d(EvaluatedParameters, oneParID " - ")
					if (EvaluatedParameters._error)
						return 
					break
				}
			}
			
			
		}
	}
}

x_EvalOneParameter(EvaluatedParameters, Environment, ElementParameters, oneParID, onePar = "")
{
	if not (onePar)
	{
		elementClass:=_Flows[Environment.FlowID].allElements[Environment.ElementID].class
		ParametrationDetails := Element_getParametrizationDetails(elementClass, Environment)
		for oneParIndex, onePar2 in ParametrationDetails
		{
		;~ d(onePar, "onePar")
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
	
	if (oneParContent = "string")
	{
		result := x_replaceVariables(Environment,ElementParameters[oneParID])
		if (onePar.WarnIfEmpty)
		{
			if (result = "")
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("String '%1%' is empty", ElementParameters[oneParID])
				return EvaluatedParameters
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
			return EvaluatedParameters
		}
		if (onePar.WarnIfEmpty)
		{
			if (evRes.result = "")
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("Result of expression '%1%' is empty", ElementParameters[oneParID])
				return EvaluatedParameters
			}
		}
		if (oneParContent = "number" and temp != "")
		{
			temp:=evRes.result
			if temp is not number
			{
				EvaluatedParameters._error := true
				EvaluatedParameters._errorMessage := lang("Result of expression '%1%' is not a number", ElementParameters[oneParID])
				return EvaluatedParameters
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
			return EvaluatedParameters
		}
		EvaluatedParameters[oneParID] := result
	}
	else if (oneParContent = "RawString")
	{
		EvaluatedParameters[oneParID] := ElementParameters[oneParID]
	}
	else
	{
		EvaluatedParameters[oneParID] := ElementParameters[oneParID]
	}
	;~ d(EvaluatedParameters, oneParID " - "  oneParContent)
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
	global
	;~ d(Environment, p_name)
	Environment.ElementExecutionValues[p_name]:=p_value
	;~ global_AllExecutionIDs[Environment.uniqueID].customValues[p_name]:=p_Value
}
x_GetExecutionValue(Environment, p_name)
{
	global
	;~ return global_AllExecutionIDs[Environment.uniqueID].customValues[p_name]
	return Environment.ElementExecutionValues[p_name]
}

x_NewExecutionFunctionObject(Environment, p_ToCallFunction, params*)
{
	oneFunctionObject:=new Class_FunctionObject(Environment, p_ToCallFunction, params*)
	
	global_AllExecutionIDs[Environment.uniqueID].ExecutionFunctionObjects[p_ToCallFunction]:=oneFunctionObject
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
	count:=0
	for oneinstanceID, oneInstance in _execution.Instances
	{
		if (oneInstance.ID = Environment.InstanceID)
		{
			count++
		}
	}
	return count
}



;exeuction in other ahk thread
x_ExecuteInNewAHKThread(Environment, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	global global_AllExecutionIDs
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
	
	
	;~ d("`n" preCode "`n" p_Code "`n" postCode)
	AhkThread("`n" preCode "`n" p_Code "`n" postCode)
	
}

ExecuteInNewAHKThread_finishedExecution(p_ExecutionID) ;Not an api function
{
	global global_AllExecutionIDs
	Environment:=x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
	;~ d(_share.temp[Environment.uniqueID],Environment.uniqueID)
	;~ d(global_AllExecutionIDs[Environment.uniqueID],Environment.uniqueID)
	functionObject:=global_AllExecutionIDs[Environment.uniqueID].ExeInNewThread.functionObject
	%functionObject%(_share.temp[Environment.uniqueID].sharedObject.varsExported)
}
;exeuction of a trigger in other ahk thread
x_TriggerInNewAHKThread(Environment, p_Code, p_VarsToImport, p_VarsToExport)
{
	global _share, global_AllActiveTriggerIDs
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
		
	;~ d("`n" preCode "`n" p_Code "`n" postCode)
	global_AllActiveTriggerIDs[Environment.uniqueID].ExeInNewThread.AHKThreadID:=AhkThread("`n" preCode "`n" p_Code "`n" postCode)
	
}
x_TriggerInNewAHKThread_Stop(Environment)
{
	ahkthread_release(global_AllActiveTriggerIDs[Environment.uniqueID].ExeInNewThread.AHKThreadID)
}
ExecuteInNewAHKThread_trigger(p_uniqueID) ;Not an api function
{
	global _share
	Environment:=global_AllActiveTriggerIDs[p_uniqueID].environment
	;~ d(Environment, "öiohöio")
	Environment.varsExportedFromExternalThread:=_share.temp[Environment.uniqueID].sharedObject.varsExported
	
	ElementClass:=Environment.ElementClass
	x_trigger(Environment)
}
x_TriggerInNewAHKThread_GetExportedValues(Environment)
{
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

x_FlowExistsByName(p_FlowName)
{
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			return True
		}
	}
	return false
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
		API_Main_enableFlow(p_FlowID)
}

x_FlowDisable(p_FlowID)
{
	if x_FlowExists(p_FlowID)
		API_Main_disableFlow(p_FlowID)
}

x_FlowStop(p_FlowID)
{
	if x_FlowExists(p_FlowID)
		API_Main_stopFlow(p_FlowID)
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
		if (oneElement.type = p_Type)
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
	if (_Flows[Environment.FlowID].flowsettings.DefaultWorkingDir)
	{
		return _settings.FlowWorkingDir
	}
	else
	{
		return _Flows[Environment.FlowID].flowsettings.workingdir
	}
}