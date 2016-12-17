
;This file provides functions which can be accessed while executing the elements.



x_replaceVariables(Environment, String, Type = "normal")
{
	global
	return Var_replaceVariables(Environment, String, Type)
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
x_GetVariable(Environment, Varname, Type = "normal")
{
	return Var_Get(Environment, Varname, Type)
}
x_getVariableType(Environment, Varname)
{
	return Var_GetType(Environment, Varname)
}
x_SetVariable(Environment, p_Varname, p_Value, p_Type = "normal", p_destination="")
{
	global
	return Var_Set(Environment, p_Varname, p_Value, p_Type, p_destination)
}
x_DeleteVariable(Environment, Varname)
{
	global
	return Var_Delete(Environment, Varname)
}


x_GetVariableLocation(Environment, Varname)
{
	global
	return Var_GetLocation(Environment, Varname)
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
		InstanceVariable_Set(Environment,oneVar.name,oneVar.value,oneVar.type)
	}
	return Var_GetListOfInstanceVars(Environment)
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
x_FlowExecuteByName(Environment, p_FlowName, p_Variables ="", p_CallBackFunction ="")
{
	global _Flows
	global _share
	random, randomnumber
	_share.temp[randomnumber]:=Object()
	_share.temp[randomnumber].CallBack:=p_CallBackFunction
	
	;Fill variables which will be passed
			;~ _share.temp[randomnumber].varstoPass:=p_Variables
	varsToPass:=p_Variables
	;~ if(p_Variables)
	;~ {
		;~ if isobject(p_Variables)
		;~ {
			;~ for forvarkey, forvarcontent in p_Variables
			;~ {
				;~ if isobject(forvarcontent)
				;~ {
					;~ tempname:=forvarcontent.name
					;~ tempvalue:=forvarcontent.value
					;~ temptype:=forvarcontent.type
					;~ if not (temptype)
						;~ temptype= normal
					;~ varsToPass[tempname]:={name: tempname, value: tempvalue, type: temptype}
				;~ }
				;~ else
				;~ {
					;~ tempname:=forvarcontent
					;~ tempObj:= InstanceVariable_GetWhole(Environment,tempname)
					;~ tempvalue:=tempObj.value
					;~ temptype:=tempObj.type
					;~ varsToPass[tempname]:={name: tempname, value: tempvalue, type: temptype}
				;~ }
			;~ }
		;~ }
		;~ else
		;~ {
			;~ loop, parse, p_Variables, % ","
			;~ {
				;~ tempname:=A_LoopField
				;~ tempObj:= InstanceVariable_GetWhole(Environment,tempname)
				;~ tempvalue:=tempObj.value
				;~ temptype:=tempObj.type
				;~ varsToPass[tempname]:={name: tempname, value: tempvalue, type: temptype}
			;~ }
		;~ }
	;~ }
	_share.temp[randomnumber].varsToPass:=varsToPass
	
	for forFlowID, forFlow in _Flows
	{
		if (forFlow.name = p_FlowName)
		{
			;~ d(_share.temp)
			API_Main_executeFlow(forFlow.id, randomnumber)
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

;For elements
x_finish(Environment, Result, Message = "")
{
	finishExecutionOfElement(Environment, Result, Message)
	
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