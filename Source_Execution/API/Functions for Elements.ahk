
;This file provides functions which can be accessed while executing the elements.



x_replaceVariables(Environment, String)
{
	global
	return Var_replaceVariables(Environment, String)
}
x_EvaluateExpression(Environment, String)
{
	global
	return Var_EvaluateExpression(Environment, String)
}
x_CheckVariableName(VarName)
{
	return Var_CheckName(VarName)
}
x_GetVariable(Environment, Varname, p_hidden = False)
{
	return Var_Get(Environment, Varname, p_hidden )
}
x_getVariableType(Environment, Varname, p_hidden = False)
{
	return Var_GetType(Environment, Varname, p_hidden )
}
x_SetVariable(Environment, p_Varname, p_Value, p_destination="", p_hidden = False)
{
	global
	return Var_Set(Environment, p_Varname, p_Value,  p_destination, p_hidden)
}
x_DeleteVariable(Environment, Varname, p_hidden = False)
{
	global
	return Var_Delete(Environment, Varname, p_hidden)
}


x_GetVariableLocation(Environment, Varname, p_hidden = False)
{
	global
	return Var_GetLocation(Environment, Varname, p_hidden)
}

x_GetMyElementID(Environment)
{
	return Environment.elementID
}


x_GetMyFlowID(Environment)
{
	return Environment.FlowID
}
x_GetMyFlowName(Environment)
{
	global _flows
	return _flows[Environment.FlowID].name
}

x_GetAllMyFlowTriggerNames(Environment)
{
	global _flows
	elements:=Object()
	for oneID, oneElement in _flows[Environment.FlowID].allElements
	{
		if (oneElement.type = "trigger")
			elements.push(oneElement.name)
	}
	return elements
}
x_GetAllMyFlowManualTriggers(Environment)
{
	global _flows
	elements:=Object()
	for oneID, oneElement in _flows[Environment.FlowID].allElements
	{
		if (oneElement.class = "trigger_manual")
			elements.push(objfullyclone(oneElement))
	}
	return elements
}

x_GetAllManualTriggersOfFlowByName(p_FlowName)
{
	global _Flows
	elements:=Object()
	
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			for oneID, oneElement in forFlow.allElements
			{
				if (oneElement.class = "trigger_manual")
					elements.push(objfullyclone(oneElement))
			}
		}
	}
	
	return elements
}



x_getAllElementsOfClass(Environment, p_Class)
{
	global _flows
	
	elements:=Object()
	for oneID, oneElement in _flows[Environment.FlowID].allElements
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


x_NewUniqueExecutionID(Environment)
{
	global
	if not IsObject(global_AllExecutionIDs)
		global_AllExecutionIDs:=Object()
	local tempID:="GUI_" Environment.instanceID "_" Environment.threadID "_" Environment.elementID
	
	global_AllExecutionIDs[tempID]:={id: tempID, instanceID: Environment.instanceID, threadID:Environment.threadID, elementID:Environment.elementID, environment: environment, customValues:Object()}
	
	return tempID
}
x_GetMyUniqueExecutionID(Environment)
{
	global
	local tempID:="GUI_" Environment.instanceID "_" Environment.threadID "_" Environment.elementID
	return tempID
}
x_DeleteMyUniqueExecutionID(Environment)
{
	global
	if isobject(Environment)
	{
		local tempID:="GUI_" Environment.instanceID "_" Environment.threadID "_" Environment.elementID
	}
	else
	{
		tempID:=Environment
	}
	global_AllExecutionIDs.delete(tempID)
}
x_GetMyEnvironmentFromExecutionID(p_ExecutionID)
{
	global
	return global_AllExecutionIDs[p_ExecutionID].environment
}
x_SetExecutionValue(p_ExecutionID, p_name, p_Value)
{
	global
	global_AllExecutionIDs[p_ExecutionID].customValues[p_name]:=p_Value
}
x_GetExecutionValue(p_ExecutionID, p_name)
{
	global
	return global_AllExecutionIDs[p_ExecutionID].customValues[p_name]
}

x_NewExecutionFunctionObject(Environment, p_ExecutionID, p_ToCallFunction, params*)
{
	oneFunctionObject:=new Class_FunctionObject(Environment, p_ToCallFunction, params*)
	
	global_AllExecutionIDs[p_ExecutionID].ExecutionFunctionObjects[p_ToCallFunction]:=oneFunctionObject
	return oneFunctionObject
}


; Function object which can be created
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
	global
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

x_FlowEnableByName(Environment, p_FlowName)
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			API_Main_enableFlow(forFlow.id)
		}
	}

}


x_FlowDisableByName(Environment, p_FlowName)
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			API_Main_disableFlow(forFlow.id)
		}
	}

}


x_TriggerEnableByName(Environment, p_FlowName, p_TriggerName="")
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			for forelementID, forelement in forFlow.allElements
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
	}

}
x_TriggerDisableByName(Environment, p_FlowName, p_TriggerName="")
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			for forelementID, forelement in forFlow.allElements
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
	}

}

x_FlowExecuteByName(Environment, p_FlowName, p_TriggerName = "", p_Variables ="", p_CallBackFunction ="")
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
	
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			;~ d(_share.temp)
			if (p_TriggerName = "")
			{
				;~ d(p_FlowName)
				API_Main_executeFlow(forFlow.id, "", randomnumber)
				return
			}
			else
			{
				;~ d(p_FlowName " - " p_TriggerName)
				for forelementID, forelement in forFlow.allElements
				{
					;~ d(forelement, p_TriggerName)
					if forelement.class = "trigger_Manual"
					{
						if (forelement.pars.id = p_TriggerName)
						{
							;~ d(forFlow.id,forelementID)
							API_Main_executeFlow(forFlow.id, forelementID, randomnumber)
							return
						}
					}
				}
			}
		}
	}

}
x_FlowStopByName(Environment, p_FlowName)
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			API_Main_stopFlow(forFlow.id)
		}
	}

}
x_isFlowEnabledByName(Environment, p_FlowName)
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			return forFlow.enabled
		}
	}
	return False
}
x_isTriggerEnabledByName(Environment, p_FlowName, p_TriggerName="")
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			for forelementID, forelement in forFlow.allElements
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
		}
	}
	return False
}
x_isFlowExecutingByName(Environment, p_FlowName)
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			return forFlow.executing
		}
	}
	return False
}

x_FlowExistsByName(Environment, p_FlowName)
{
	global _Flows
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			return True
		}
	}
	Return False
}


x_InstanceStop(Environment)
{
	global _execution
	
	stopInstance(_execution.Instances[Environment.instanceID])
	

}

x_GetThreadCountInCurrentInstance(Environment)
{
	global _execution
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

x_GetFullPath(Environment, p_Path)
{
	global _Flows
	path:=p_Path
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",path)
		path:=_Flows[Environment.FlowID].flowsettings.workingdir "\" path
	return path
}

x_ExecuteInNewThread(Environment, p_uniqueID, p_functionObject, p_Code, p_VarsToImport, p_VarsToExport)
{
	global _share, global_AllExecutionIDs
	if not isobject(global_AllExecutionIDs[p_uniqueID])
		global_AllExecutionIDs[p_uniqueID]:=object()
	global_AllExecutionIDs[p_uniqueID].ExeInNewThread:=object()
	global_AllExecutionIDs[p_uniqueID].ExeInNewThread.functionObject:=p_functionObject
	
	_share.temp[p_uniqueID]:= Object()
	_share.temp[p_uniqueID].sharedObject := CriticalObject()
	_share.temp[p_uniqueID].sharedObject.varsToImport:=p_VarsToImport
	_share.temp[p_uniqueID].sharedObject.varsToExport:=p_VarsToExport
	_share.temp[p_uniqueID].sharedObject.varsExported:=Object()
	;~ d(_share.temp[p_uniqueID])
	preCode := "ahf_uniqueID :=""" p_uniqueID """`n"
	preCode .= "ahf_sharedObject := CriticalObject(" (&_share.temp[p_uniqueID].sharedObject) ")`n"
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
x_ExecuteInNewThread_finishedExecution(p_uniqueID)
{
	global _share, global_AllExecutionIDs
	;~ d(_share.temp[p_uniqueID],p_uniqueID)
	;~ d(global_AllExecutionIDs[p_uniqueID],p_uniqueID)
	functionObject:=global_AllExecutionIDs[p_uniqueID].ExeInNewThread.functionObject
	%functionObject%(_share.temp[p_uniqueID].sharedObject.varsExported)
}


x_log(Environment, LoggingText, loglevel = 2)
{
	global _flows
	logger("f" loglevel, "Flow: " _flows[Environment.FlowID].name " (" Environment.FlowID ") - Element " _flows[Environment.FlowID].allElements[Environment.elementID].name " (" Environment.elementID "): " LoggingText)
}


;For elements
x_finish(Environment, Result, Message = "")
{
	finishExecutionOfElement(Environment, Result, Message)
	
}

;For loops
x_getEntryPoint(Environment)
{
	return Environment.ElementEntryPoint
}

;For triggers
x_trigger(Environment, triggerVars="")
{
	Environment.triggerVars:=triggerVars
	newInstance(Environment)
}

x_enabled(Environment, Result, Message = "")
{
	global
	saveResultOfTriggerEnabling(Environment, Result, Message)
}
x_disabled(Environment, Result, Message = "")
{
	global
	saveResultOfTriggerDisabling(Environment, Result, Message)
}


;While editing

x_Par_Disable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
	;~ return ElementSettings.field.enable(p_ParameterID,not p_TrueOrFalse)
}
x_Par_Enable(Environment,p_ParameterID, p_TrueOrFalse = True)
{
	;~ return ElementSettings.field.enable(p_ParameterID,p_TrueOrFalse)
}
x_Par_SetValue(Environment,p_ParameterID, p_Value)
{
	;~ return ElementSettings.field.setvalue(p_Value,p_ParameterID)
}
x_Par_GetValue(Environment,p_ParameterID)
{
	;~ return ElementSettings.field.getvalue(p_ParameterID)
}
x_Par_SetChoices(Environment,p_ParameterID, p_Choices)
{
	
}

;everywhere
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
