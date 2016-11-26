
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
x_SetVariable(Environment, Varname, Value, Type = "normal", destination="")
{
	global
	return Var_Set(Environment, Varname, Value, Type, destination)
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
x_DeleteMyUniqueExecutionID(p_ExecutionID)
{
	global
	global_AllExecutionIDs.delete(p_ExecutionID)
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

x_NewExecutionFunctionObject(Environment, p_ExecutionID, p_ToCallFunction)
{
	oneFunctionObject:=new FunctionObject(Environment, p_ToCallFunction)
	global_AllExecutionIDs[p_ExecutionID].ExecutionFunctionObjects[p_ToCallFunction]:=oneFunctionObject
	return oneFunctionObject
}


; Function object which can be created
class FunctionObject 
{
    __New(Environment, ToCallFunction) 
	{
        this.Environment := Environment
        this.FunctionObject := ObjBindMethod(this, CallFunction)
		this.ToCallFunction := ToCallFunction
		return this.FunctionObject
    }
   
    CallFunction() 
	{
        ToCallFunction:=this.ToCallFunction
		%ToCallFunction%(this.Environment)
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

;For elements
x_finish(Environment, Result, Message = "")
{
	finishExecutionOfElement(Environment, Result, Message = "")
	
}
;For triggers
x_trigger(Environment)
{
	global
	
	newInstance(_flows[Environment.flowID])
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